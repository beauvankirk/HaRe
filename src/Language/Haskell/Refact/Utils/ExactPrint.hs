{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE RankNTypes #-}
module Language.Haskell.Refact.Utils.ExactPrint
  (
    replace
  , replaceAnnKey
  , copyAnn

  , setAnnKeywordDP
  , clearPriorComments
  , balanceAllComments
  , locate
  , addEmptyAnn
  , addAnnValWithDP
  , addAnnVal
  , addAnn
  , zeroDP
  , setDP
  , handleParseResult
  , removeAnns
  , synthesizeAnns
  , addNewKeyword
  , addNewKeywords
  , copyAnnDP
  , getDeltaPos
  ) where

import qualified GHC           as GHC

import qualified Data.Generics as SYB
import Control.Monad

import Language.Haskell.GHC.ExactPrint.Transform
import Language.Haskell.GHC.ExactPrint.Types
import Language.Haskell.GHC.ExactPrint.Utils
import Language.Haskell.Refact.Utils.GhcUtils

import Language.Haskell.Refact.Utils.Monad
import Language.Haskell.Refact.Utils.MonadFunctions

import qualified Data.Map as Map

-- ---------------------------------------------------------------------

-- ++AZ++:TODO: Move this to ghc-exactprint
-- |The annotations are keyed to the constructor, so if we replace a qualified
-- with an unqualified RdrName or vice versa we have to rebuild the key for the
-- appropriate annotation.
replaceAnnKey :: (SYB.Data old,SYB.Data new)
  => GHC.Located old -> GHC.Located new -> Anns -> Anns
replaceAnnKey old new ans =
  case Map.lookup (mkAnnKey old) ans of
    Nothing -> ans
    Just v ->  anns'
      where
        anns1 = Map.delete (mkAnnKey old) ans
        anns' = Map.insert (mkAnnKey new) v anns1


-- ---------------------------------------------------------------------

-- ++AZ++ TODO: migrate this to ghc-exactprint
copyAnn :: (SYB.Data old,SYB.Data new)
  => GHC.Located old -> GHC.Located new -> Anns -> Anns
copyAnn old new ans =
  case Map.lookup (mkAnnKey old) ans of
    Nothing -> ans
    Just v  -> Map.insert (mkAnnKey new) v ans

-- ---------------------------------------------------------------------

-- | Replaces an old expression with a new expression
replace :: AnnKey -> AnnKey -> Anns -> Maybe Anns
replace old new ans = do
  let as = ans
  oldan <- Map.lookup old as
  newan <- Map.lookup new as
  let newan' = Ann
                { annEntryDelta        = annEntryDelta oldan
                -- , annDelta             = annDelta oldan
                -- , annTrueEntryDelta    = annTrueEntryDelta oldan
                , annPriorComments     = annPriorComments oldan
                , annFollowingComments = annFollowingComments oldan
                , annsDP               = moveAnns (annsDP oldan) (annsDP newan)
                , annSortKey           = annSortKey oldan
                , annCapturedSpan      = annCapturedSpan oldan
                }
  return ((\anns -> Map.delete old . Map.insert new newan' $ anns) ans)

-- ---------------------------------------------------------------------

-- | Shift the first output annotation into the correct place
moveAnns :: [(KeywordId, DeltaPos)] -> [(KeywordId, DeltaPos)] -> [(KeywordId, DeltaPos)]
moveAnns [] xs        = xs
moveAnns ((_, dp): _) ((kw, _):xs) = (kw,dp) : xs
moveAnns _ []         = []

-- ---------------------------------------------------------------------

-- |Change the @DeltaPos@ for a given @KeywordId@ if it appears in the
-- annotation for the given item.
setAnnKeywordDP :: (SYB.Data a) => GHC.Located a -> KeywordId -> DeltaPos -> Transform ()
setAnnKeywordDP la kw dp = modifyAnnsT changer
  where
    changer ans = case Map.lookup (mkAnnKey la) ans of
      Nothing -> ans
      Just an -> Map.insert (mkAnnKey la) (an {annsDP = map update (annsDP an)}) ans
    update (kw',dp')
      | kw == kw' = (kw',dp)
      | otherwise = (kw',dp')

-- ---------------------------------------------------------------------

-- |Remove any preceding comments from the given item
clearPriorComments :: (SYB.Data a) => GHC.Located a -> Transform ()
clearPriorComments la = do
  edp <- getEntryDPT la
  modifyAnnsT $ \ans ->
    case Map.lookup (mkAnnKey la) ans of
      Nothing -> ans
      Just an -> Map.insert (mkAnnKey la) (an {annPriorComments = [] }) ans
  setEntryDPT la edp

-- ---------------------------------------------------------------------

balanceAllComments :: SYB.Data a => GHC.Located a -> Transform (GHC.Located a)
balanceAllComments la
  -- Must be top-down
  = everywhereM' (SYB.mkM inMod
                     `SYB.extM` inExpr
                     `SYB.extM` inMatch
                     `SYB.extM` inStmt
                   ) la
  where
    inMod :: GHC.ParsedSource -> Transform (GHC.ParsedSource)
    inMod m = doBalance m

    inExpr :: GHC.LHsExpr GhcPs -> Transform (GHC.LHsExpr GhcPs)
    inExpr e = doBalance e

    inMatch :: (GHC.LMatch GhcPs (GHC.LHsExpr GhcPs)) -> Transform (GHC.LMatch GhcPs (GHC.LHsExpr GhcPs))
    inMatch m = doBalance m

    inStmt :: GHC.LStmt GhcPs (GHC.LHsExpr GhcPs) -> Transform (GHC.LStmt GhcPs (GHC.LHsExpr GhcPs))
    inStmt s = doBalance s

    -- |Balance all comments between adjacent decls, as well as pushing all
    -- trailing comments to the right place.
    {-
    e.g., for

        foo = do
          return x
            where
               x = ['a'] -- do

        bar = undefined

    the "-- do" comment must end up in the trailing comments for "x = ['a']"
    -}
    doBalance t = do
      decls <- hsDecls t
      let
        go [] = return []
        go [x] = return [x]
        go (x1:x2:xs) = do
          balanceComments x1 x2
          go (x2:xs)
      _ <- go decls
      -- replaceDecls t decls'
      unless (null decls) $ moveTrailingComments t (last decls)
      return t

--This generates a unique location and wraps the given ast chunk with that location
--Also adds an empty annotation at that location
locate :: (SYB.Data a) => a -> RefactGhc (GHC.Located a)
locate ast = do
  loc <- liftT uniqueSrcSpanT
  let res = (GHC.L loc ast)
  addEmptyAnn res
  return res

--Adds an empty annotation at the provided location
addEmptyAnn :: (SYB.Data a) => GHC.Located a -> RefactGhc ()
addEmptyAnn a = liftT $ addAnn a annNone

addAnnValWithDP :: (SYB.Data a) => GHC.Located a -> DeltaPos -> RefactGhc ()
-- addAnnValWithDP a dp = addAnn a valAnn
--     where valAnn = annNone {annEntryDelta = dp, annsDP = [(G GHC.AnnVal, DP (0,0))]}
addAnnValWithDP a dp = liftT $ addSimpleAnnT a dp [(G GHC.AnnVal, DP (0,0))]

--Adds an "AnnVal" annotation at the provided location
addAnnVal :: (SYB.Data a) => GHC.Located a -> RefactGhc ()
addAnnVal a = addAnnValWithDP a (DP (0,1))

-- TODO:AZ use the standard API instead
-- | Adds the given annotation at the provided location
-- addAnn :: (SYB.Data a) => GHC.Located a -> Annotation -> RefactGhc ()
addAnn :: (SYB.Data a) => GHC.Located a -> Annotation -> Transform ()
addAnn a ann = do
  -- currAnns <- fetchAnnsFinal
  -- let k = mkAnnKey a
  -- setRefactAnns $ Map.insert k ann currAnns
  let k = mkAnnKey a
  modifyAnnsT (\currAnns -> Map.insert k ann currAnns)


-- TODO:AZ replace this with the ghc-exactprint one directly
-- |Sets the entry delta position of an ast chunk
setDP :: (SYB.Data a) => DeltaPos -> GHC.Located a -> RefactGhc ()
setDP dp ast = do
  liftT $ setEntryDPT ast dp
  -- currAnns <- fetchAnnsFinal
  -- let k = mkAnnKey ast
  --     mv = Map.lookup k currAnns
  -- case mv of
  --   Nothing -> return ()
  --   Just v -> addAnn ast (v {annEntryDelta = dp})

--Resets the given AST chunk's delta position to zero.
zeroDP :: (SYB.Data a) => GHC.Located a -> RefactGhc ()
zeroDP = setDP (DP (0,0))

--This just pulls out the successful result from an exact print parser or throws an error if the parse was unsuccessful.
handleParseResult :: String -> Either (GHC.SrcSpan, String) (Anns, a) -> RefactGhc (Anns, a)
handleParseResult msg e = case e of
  (Left (_, errStr)) -> error $ "The parse from: " ++ msg ++ " with error: " ++ errStr
  (Right res) -> return res

-- This creates an empty annotation for every located item where an annotation does not already exist in the given AST chunk
synthesizeAnns :: (SYB.Data a) => a -> RefactGhc a
synthesizeAnns = generic `SYB.ext2M` located
  where generic :: SYB.Data a => a -> RefactGhc a
        generic a = do
          _ <- SYB.gmapM synthesizeAnns a
          return a
        located :: (SYB.Data b, SYB.Data loc) => GHC.GenLocated loc b -> RefactGhc (GHC.GenLocated loc b)
        located b@(GHC.L ss a) = case SYB.cast ss of
          Just (s :: GHC.SrcSpan) -> do
            --logm $ "Located found: " ++ (show $ toConstr a)
            anns <- fetchAnnsFinal
            let castRes = (GHC.L s a)
                ann = getAnnotationEP castRes anns
            --logm $ "Found ann: " ++ show ann
            case ann of
              Nothing -> do
                --logm "No ann found for located item"
                let newKey = mkAnnKey castRes
                    newAnns = Map.insert newKey annNone anns
                setRefactAnns newAnns
                return ()
              _ -> return ()
            _ <- SYB.gmapM synthesizeAnns b
            return b
          Nothing ->
            return b

-- This removes all the annotations associated with the given AST chunk.
removeAnns :: (SYB.Data a) => a -> RefactGhc a
removeAnns = generic `SYB.ext2M` located
  where generic :: SYB.Data a => a -> RefactGhc a
        generic a = do
          _ <- SYB.gmapM synthesizeAnns a
          return a
        located :: (SYB.Data b, SYB.Data loc) => GHC.GenLocated loc b -> RefactGhc (GHC.GenLocated loc b)
        located b@(GHC.L ss a) = case SYB.cast ss of
          Just (s :: GHC.SrcSpan) -> do
            anns <- fetchAnnsFinal
            let k = mkAnnKey (GHC.L s a)
            logm $ "Deleting ann at: " ++ (show s)
            setRefactAnns $ Map.delete k anns
            _ <- SYB.gmapM removeAnns b
            return b
          Nothing -> return b

--This takes in a located ast chunk and adds the provided keyword and delta position into the annsDP list
--If there is not annotation associated with the chunk nothing happens
addNewKeyword :: (SYB.Data a) => (KeywordId, DeltaPos) -> GHC.Located a -> RefactGhc ()
addNewKeyword entry a = do
  anns <- liftT getAnnsT
  let key = mkAnnKey a
      mAnn = Map.lookup key anns
  case mAnn of
    Nothing -> return ()
    (Just ann) -> do
      let newAnn = ann{annsDP = (entry:(annsDP ann))}
      setRefactAnns $ Map.insert key newAnn anns

addNewKeywords :: (SYB.Data a) => [(KeywordId, DeltaPos)] -> GHC.Located a -> RefactGhc ()
addNewKeywords entries a = mapM_ ((flip addNewKeyword) a) entries

getDeltaPos :: (SYB.Data a) => GHC.Located a -> Anns -> Maybe DeltaPos
getDeltaPos a ans = Map.lookup (mkAnnKey a) ans >>= (\v -> return (annEntryDelta v))

copyAnnDP :: (SYB.Data old,SYB.Data new)
  => GHC.Located old -> GHC.Located new -> Anns -> Anns
copyAnnDP old new ans =
  case Map.lookup (mkAnnKey old) ans of
    Nothing -> ans
    Just v  -> Map.insert (mkAnnKey new) newAnn ans
      where
        dp = annEntryDelta v
        newAnn = annNone {annEntryDelta = dp}
