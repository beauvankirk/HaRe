{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE RankNTypes #-}
module Language.Haskell.Refact.Utils.ExactPrint
  (
    resequenceAnnotations
  , uniqueSrcSpan
  , addAnnKeywords
  , setOffsets
  , setOffset
  , setLocatedOffsets
  , deleteAnnotation
  , setLocatedDp
  , extractAnnsEP
  , mergeAnns
  , deleteAnnotations
  , replace
  , replaceAnnKey
  , mkKey
  , setColRec
  , getOriginalPos

  -- * Operations
  , transferEntryDP

  -- * TransForm
  , Transform
  , runTransform
  , logTr
  ) where

import qualified FastString    as GHC
import qualified GHC

import qualified Data.Generics as SYB
--import qualified GHC.SYB.Utils as SYB

import Language.Haskell.Refact.Utils.Monad
import Language.Haskell.Refact.Utils.Types
import Language.Haskell.GHC.ExactPrint.Types
import Language.Haskell.GHC.ExactPrint.Utils

import Control.Monad.RWS
import Data.List
import Data.Maybe

import qualified Data.Map as Map

-- ---------------------------------------------------------------------

resequenceAnnotations :: (SYB.Data t)
                      => GHC.Located t -> RefactGhc (GHC.Located t,Anns)
resequenceAnnotations t = do
  t1 <- insertUniqueSrcSpans t
  let aa = extractAnnsEP t1
      bb = uniqueSpansOnly aa
  logm $ "resequenceAnnotations:annsEP=" ++ (show aa)
  -- logm $ "resequenceAnnotations:locatedConstr=" ++ (SYB.showConstr locatedConstructor)
  return (t1,bb)


-- ---------------------------------------------------------------------

-- | Replace empty source spans with a unique SrcSpan which is used as
-- a key. It doesn't matter what it is.
insertUniqueSrcSpans :: (SYB.Data t) => GHC.Located t -> RefactGhc (GHC.Located t)
insertUniqueSrcSpans t
  = SYB.everywhereM (SYB.mkM newSrcSpan) t
  where
    newSrcSpan :: GHC.SrcSpan -> RefactGhc GHC.SrcSpan
    newSrcSpan ss = if ss == GHC.noSrcSpan
                      then uniqueSrcSpan
                      else return ss

-- ---------------------------------------------------------------------
-- | Filter annotations to get ones corresponding to SrcSpans.
uniqueSpansOnly :: Anns -> Anns
uniqueSpansOnly anns
  = Map.filterWithKey (\(AnnKey ss _) _ -> isUniqueSrcSpan ss) anns

-- ---------------------------------------------------------------------

-- TODO: do we have to match the filename for GHC compare functions?
uniqueSrcSpan :: RefactGhc GHC.SrcSpan
uniqueSrcSpan = do
  s <- get
  col <- gets rsSrcSpanCol
  put s { rsSrcSpanCol = col + 1 }

  let pos = GHC.mkSrcLoc (GHC.mkFastString "HaRe") (-1) col
  return $ GHC.mkSrcSpan pos pos

isUniqueSrcSpan :: GHC.SrcSpan -> Bool
isUniqueSrcSpan ss = srcSpanStartLine ss == -1

-- ---------------------------------------------------------------------

-- |Get the map of (SrcSpan,AnnConName) with empty annotations
extractAnnsEP :: forall t. (SYB.Data t) => t -> Anns
extractAnnsEP t = Map.fromList as
  where
    sts = extractSrcSpanConName t
    as :: [(AnnKey, Annotation)]
    as = map (\k -> (k, annNone)) sts

{-
++AZ++ Temporarily commenting this output
locFold :: forall r b . (SYB.Data b) => (r -> r -> r) -> (forall a . (SYB.Data a) => GHC.Located a -> r) ->  r -> b -> r
locFold f g v nil = generic v
  where generic :: b -> r
        generic t =
          if SYB.showConstr (SYB.toConstr t) == "L" -- SYB.toConstr t == locatedConstructor
            then
              g (GHC.L
                (ghead "extractAnns" (SYB.gmapQi 0 getSrcSpan t))
                (SYB.gmapQi 1 id t))
                `f` SYB.gmapQi 1 generic t
             else foldr f nil (SYB.gmapQ generic t)
        getSrcSpan :: forall d. SYB.Data d => d -> [GHC.SrcSpan]
        getSrcSpan = SYB.mkQ [] getSrcSpan'
          where
            getSrcSpan' :: GHC.SrcSpan -> [GHC.SrcSpan]
            getSrcSpan' ss = [ss]
-}

extractSrcSpanConName :: forall t. (SYB.Data t) => t -> [AnnKey]
extractSrcSpanConName  =
  generic
  where generic :: (SYB.Data a) => a -> [AnnKey]
        generic t =
          if SYB.showConstr (SYB.toConstr t) == "L" -- SYB.toConstr t == locatedConstructor
            then [ AnnKey
                    (ghead "extractAnns" (SYB.gmapQi 0 getSrcSpan t))
                    (SYB.gmapQi 1 getConName t)
                 ]
                  ++ SYB.gmapQi 1 extractSrcSpanConName t
            else concat (SYB.gmapQ extractSrcSpanConName t)

        getSrcSpan :: forall d. SYB.Data d => d -> [GHC.SrcSpan]
        getSrcSpan = SYB.mkQ [] getSrcSpan'
          where
            getSrcSpan' :: GHC.SrcSpan -> [GHC.SrcSpan]
            getSrcSpan' ss = [ss]

        getConName :: forall d. SYB.Data d => d -> AnnConName
        getConName = annGetConstr


-- ---------------------------------------------------------------------

addAnnKeywords :: Anns -> AnnConName -> [(KeywordId, DeltaPos)] -> Anns
addAnnKeywords anns conName ks = Map.insert (AnnKey ss conName) (annNone {annsDP = ks}) anns
  where
    -- First find the first srcspan having the conName
    -- MP: First in what sense?
    AnnKey ss _ = ghead "addAnnKeywords" . filter (\(AnnKey _ s) -> s == conName) $ Map.keys anns

-- ---------------------------------------------------------------------

replaceAnnKey :: (SYB.Data old,SYB.Data new)
  => Anns -> GHC.Located old -> GHC.Located new -> Anns
replaceAnnKey anns old new =
  case Map.lookup (mkAnnKey old) anns of
    Nothing -> anns
    Just v -> anns'
      where
        anns1 = Map.delete (mkAnnKey old) anns
        anns' = Map.insert (mkAnnKey new) v anns1

-- ---------------------------------------------------------------------
-- |Update the DeltaPos for the given annotation keys
setOffsets :: Anns -> [(AnnKey,Annotation)] -> Anns
setOffsets anne kvs = foldl' setOffset anne kvs

-- |Update the DeltaPos for the given annotation key/val
setOffset :: Anns -> (AnnKey, Annotation) -> Anns
setOffset anne (k, Ann dp col _) = case
  Map.lookup k anne of
    Nothing           -> Map.insert k (Ann dp col []) anne
    Just (Ann _ _ ks) -> Map.insert k (Ann dp col ks) anne

-- |Update the DeltaPos for the given annotation keys
setLocatedOffsets :: (SYB.Data a) => Anns -> [(GHC.Located a,Annotation)] -> Anns
setLocatedOffsets anne kvs = foldl' setLocatedDp anne kvs

setLocatedDp :: (SYB.Data a) => Anns -> (GHC.Located a, Annotation) ->  Anns
setLocatedDp aane (loc, annVal) = setOffset aane (mkKey loc,annVal)

-- ---------------------------------------------------------------------

-- | Replaces an old expression with a new expression
replace :: AnnKey -> AnnKey -> Anns -> Maybe Anns
replace old new as = do
  oldan <- Map.lookup old as
  newan <- Map.lookup new as
  let newan' = Ann
                { annEntryDelta = annEntryDelta oldan
                , annDelta      = annDelta oldan
                , annsDP        = moveAnns (annsDP oldan) (annsDP newan)
                }
  return . Map.delete old . Map.insert new newan' $ as

-- ---------------------------------------------------------------------

-- |Take the annEntryDelta associated with the first item and associate it with the second.
transferEntryDP :: (SYB.Data a, SYB.Data b) => Anns -> GHC.Located a -> GHC.Located b -> Anns
transferEntryDP anns a b = anns'
  where
    maybeAnns = do
      anA <- Map.lookup (mkKey a) anns
      anB <- Map.lookup (mkKey b) anns
      let anB'  = anB { annEntryDelta = annEntryDelta anA }
      -- return (Map.insert (mkKey b) anB' anns)
      return (error $ "transferEntryDP: (mkKey a,mkKey b,anA,anB,anB')" ++ showGhc (mkKey a,mkKey b,anA,anB,anB') )
    anns' = fromMaybe
              (error $ "transferEntryDP: lookup failed (a,b)=" ++ show (mkKey a,mkKey b))
              maybeAnns

-- ---------------------------------------------------------------------

mkKey :: (SYB.Data a) => GHC.Located a -> AnnKey
mkKey (GHC.L l s) = AnnKey l (annGetConstr s)


-- | Shift the first output annotation into the correct place
moveAnns :: [(KeywordId, DeltaPos)] -> [(KeywordId, DeltaPos)] -> [(KeywordId, DeltaPos)]
moveAnns [] xs        = xs
moveAnns ((_, dp): _) ((kw, _):xs) = (kw,dp) : xs


-- | Delete an annotation
deleteAnnotation :: AnnKey -> KeywordId -> Anns -> Anns
deleteAnnotation k kw =
  Map.adjust (\(s@Ann{annsDP}) -> s { annsDP = filter (\x -> fst x /= kw) annsDP}) k

mergeAnns :: Anns -> Anns -> Anns
mergeAnns = Map.unionWith (<>)

deleteAnnotations :: [(AnnKey, KeywordId)] -> Anns -> Anns
deleteAnnotations vs anne = foldr (uncurry deleteAnnotation) anne vs

-- -------------------------

-- | Recursively change the col offsets
setColRec :: (SYB.Data a) => (ColDelta -> ColDelta) -> a -> (Anns -> Anns)
setColRec f loc = transform loc
  where
    transform :: SYB.Data a => a -> (Anns -> Anns)
    transform t =
          if SYB.showConstr (SYB.toConstr t) == "L" -- SYB.toConstr t == locatedConstructor
            then setCol f (ghead "hereh" $ SYB.gmapQi 0 getSrcSpan t)
                          (SYB.gmapQi 1 getConName t)
                  . SYB.gmapQi 1 transform t
            else foldr (.) id (SYB.gmapQ transform t)
    getSrcSpan :: forall d. SYB.Data d => d -> [GHC.SrcSpan]
    getSrcSpan = SYB.mkQ [] getSrcSpan'
      where
        getSrcSpan' :: GHC.SrcSpan -> [GHC.SrcSpan]
        getSrcSpan' ss = [ss]

    getConName :: forall d. SYB.Data d => d -> AnnConName
    getConName = annGetConstr

setCol :: (ColDelta -> ColDelta) -> GHC.SrcSpan -> AnnConName -> (Anns -> Anns)
setCol f ss cn anns =
  let key = AnnKey ss cn
      res = Map.adjust (\s -> s { annDelta = f (annDelta s) }) key anns in
      res


-- ---------------------------------------------------------------------

getOriginalPos :: (SYB.Data a) => Anns -> GHC.Located a -> KeywordId -> (Pos,DeltaPos)
getOriginalPos ann la@(GHC.L ss _) kw =
  let
    an = gfromJust ("getOriginalPos" ++ showGhc (ss,kw)) $ getAnnotationEP la ann
    mdp = lookup kw (annsDP an)
  in case mdp of
    Nothing -> ((0,0),DP (0,0))
    Just dp@(DP (ro,co)) -> ((ro + srcSpanStartLine ss, co + srcSpanStartColumn ss),dp)

-- ---------------------------------------------------------------------

-- | Monad type for updating the AST and managing the annotations at the same
-- time. The W state is used to generate logging information if required.
type Transform a = RWS () [String] Anns a

runTransform :: Anns ->Transform a -> (a,Anns,[String])
runTransform ans f = runRWS f () ans

logTr :: String -> Transform ()
logTr str = tell [str]
