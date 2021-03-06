{-# LANGUAGE CPP #-}
{-# LANGUAGE StandaloneDeriving #-}
module Language.Haskell.Refact.Refactoring.Case
  ( ifToCase
  , compIfToCase
  ) where

import qualified Data.Generics         as SYB

import qualified BasicTypes    as GHC
import qualified GHC           as GHC

import qualified GhcModCore as GM (Options(..))
import Language.Haskell.Refact.API

-- To be moved into HaRe API
import Language.Haskell.GHC.ExactPrint
import Language.Haskell.GHC.ExactPrint.Types
import Language.Haskell.GHC.ExactPrint.Utils

import System.Directory
import qualified Data.Map as Map
-- import Debug.Trace

-- ---------------------------------------------------------------------

-- | Convert an if expression to a case expression
ifToCase :: RefactSettings -> GM.Options -> FilePath -> SimpPos -> SimpPos -> IO [FilePath]
ifToCase settings opts fileName beginPos endPos = do
  absFileName <- normaliseFilePath fileName
  runRefacSession settings opts (compIfToCase absFileName beginPos endPos)

compIfToCase :: FilePath -> SimpPos -> SimpPos -> RefactGhc [ApplyRefacResult]
compIfToCase fileName beginPos endPos = do
       parseSourceFileGhc fileName
       parsed <- getRefactParsed
       oldAnns <- liftT getAnnsT
       -- logm $ "Case.compIfToCase:parsed=" ++ (showAnnData oldAnns 0 parsed) -- ++AZ++
       let expr = locToExp beginPos endPos parsed
       case expr of
         Just exp1@(GHC.L _ (GHC.HsIf {}))
                -> do (refactoredMod,_) <- applyRefac (doIfToCaseInternal exp1) RSAlreadyLoaded
                      return [refactoredMod]
         _      -> error $ "You haven't selected an if-then-else  expression!" -- (show (beginPos,endPos,fileName)) ++ "]:" ++ (showAnnData mempty 0 $ ast)

doIfToCaseInternal ::
  GHC.Located (GHC.HsExpr GhcPs)
  -> RefactGhc ()
doIfToCaseInternal expr = do
  rs <- getRefactParsed
  reallyDoIfToCase expr rs

reallyDoIfToCase ::
  GHC.Located (GHC.HsExpr GhcPs)
  -> GHC.ParsedSource
  -> RefactGhc ()
reallyDoIfToCase expr p = do

   p2 <- SYB.everywhereM (SYB.mkM inExp) p
   putRefactParsed p2 mempty
   return ()
       where
         inExp :: (GHC.Located (GHC.HsExpr GhcPs)) -> RefactGhc (GHC.Located (GHC.HsExpr GhcPs))
         inExp exp1@(GHC.L _ (GHC.HsIf {}))
           | sameOccurrence expr exp1
           = do
               newExp <- ifToCaseTransform exp1
               return newExp

         inExp e = return e

-- |Actually do the transformation
ifToCaseTransform :: GHC.Located (GHC.HsExpr GhcPs)
                  -> RefactGhc (GHC.Located (GHC.HsExpr GhcPs))
#if __GLASGOW_HASKELL__ >= 806
ifToCaseTransform li@(GHC.L _ (GHC.HsIf _ _se e1 e2 e3)) = do
#else
ifToCaseTransform li@(GHC.L _ (GHC.HsIf _se e1 e2 e3)) = do
#endif
  caseLoc        <- liftT uniqueSrcSpanT -- HaRe:-1:1
  trueMatchLoc   <- liftT uniqueSrcSpanT -- HaRe:-1:2
  trueLoc1       <- liftT uniqueSrcSpanT -- HaRe:-1:3
  trueLoc        <- liftT uniqueSrcSpanT -- HaRe:-1:4
  trueRhsLoc     <- liftT uniqueSrcSpanT -- HaRe:-1:5
  falseLoc1      <- liftT uniqueSrcSpanT -- HaRe:-1:6
  falseLoc       <- liftT uniqueSrcSpanT -- HaRe:-1:7
  falseMatchLoc  <- liftT uniqueSrcSpanT -- HaRe:-1:8
  falseRhsLoc    <- liftT uniqueSrcSpanT -- HaRe:-1:9
#if __GLASGOW_HASKELL__ > 710
  matchesLoc     <- liftT uniqueSrcSpanT -- HaRe:-1:10
  lbTrueLoc      <- liftT uniqueSrcSpanT -- HaRe:-1:11
  lbFalseLoc     <- liftT uniqueSrcSpanT -- HaRe:-1:11
#endif
  let trueName  = mkRdrName "True"
  let falseName = mkRdrName "False"
#if __GLASGOW_HASKELL__ >= 806
  let ret = GHC.L caseLoc (GHC.HsCase GHC.noExt e1
#else
  let ret = GHC.L caseLoc (GHC.HsCase e1
#endif
             (GHC.MG
#if __GLASGOW_HASKELL__ >= 806
              GHC.noExt 
#endif
              (
#if __GLASGOW_HASKELL__ > 710
              GHC.L matchesLoc
#endif
              [
#if __GLASGOW_HASKELL__ >= 806
                (GHC.L trueMatchLoc $ GHC.Match GHC.noExt 
#else
                (GHC.L trueMatchLoc $ GHC.Match
#endif
#if __GLASGOW_HASKELL__ <= 710
                 Nothing
#elif __GLASGOW_HASKELL__ <= 800
                 GHC.NonFunBindMatch
#else
                 GHC.CaseAlt
#endif
                 [
                   GHC.L trueLoc1 $ GHC.ConPatIn (GHC.L trueLoc trueName) (GHC.PrefixCon [])
                 ]
#if __GLASGOW_HASKELL__ >= 804
#else
                 Nothing
#endif
                 (GHC.GRHSs
#if __GLASGOW_HASKELL__ >= 806
                   GHC.noExt 
#endif
                   [
#if __GLASGOW_HASKELL__ >= 806
                     GHC.L trueRhsLoc $ GHC.GRHS GHC.noExt [] e2
#else
                     GHC.L trueRhsLoc $ GHC.GRHS [] e2
#endif
                   ]
                   (
#if __GLASGOW_HASKELL__ > 710
                    GHC.L lbTrueLoc
#endif
#if __GLASGOW_HASKELL__ >= 806
                   (GHC.EmptyLocalBinds GHC.noExt)))
#else
                   GHC.EmptyLocalBinds))
#endif
                )
              , (GHC.L falseMatchLoc $ GHC.Match
#if __GLASGOW_HASKELL__ >= 806
                  GHC.noExt 
#endif
#if __GLASGOW_HASKELL__ <= 710
                  Nothing
#elif __GLASGOW_HASKELL__ <= 800
                  GHC.NonFunBindMatch
#else
                  GHC.CaseAlt
#endif
                 [
                   GHC.L falseLoc1 $ GHC.ConPatIn (GHC.L falseLoc falseName) (GHC.PrefixCon [])
                 ]
#if __GLASGOW_HASKELL__ >= 804
#else
                 Nothing
#endif
                 (GHC.GRHSs
#if __GLASGOW_HASKELL__ >= 806
                   GHC.noExt 
#endif
                   [
#if __GLASGOW_HASKELL__ >= 806
                     GHC.L falseRhsLoc $ GHC.GRHS GHC.noExt [] e3
#else
                     GHC.L falseRhsLoc $ GHC.GRHS [] e3
#endif
                   ]
                   (
#if __GLASGOW_HASKELL__ > 710
                   GHC.L lbFalseLoc
#endif
#if __GLASGOW_HASKELL__ >= 806
                   (GHC.EmptyLocalBinds GHC.noExt)))
#else
                   GHC.EmptyLocalBinds))
#endif
                )
              ])
#if __GLASGOW_HASKELL__ < 806
              [] GHC.placeHolderType
#endif
              GHC.FromSource))

  oldAnns <- liftT $ getAnnsT
  let annIf   = gfromJust "Case.annIf"   $ getAnnotationEP li oldAnns
  let annThen = gfromJust "Case.annThen" $ getAnnotationEP e2 oldAnns
  let annElse = gfromJust "Case.annElse" $ getAnnotationEP e3 oldAnns
  logm $ "Case:annIf="   ++ show annIf
  logm $ "Case:annThen=" ++ show annThen
  logm $ "Case:annElse=" ++ show annElse

  -- AZ:TODO: under some circumstances the GRHS annotations need LineSame, in others LineChanged.
  let ifDelta     = gfromJust "Case.ifDelta"     $ lookup (G GHC.AnnIf) (annsDP annIf)
  -- let ifSpanEntry = gfromJust "Case.ifSpanEntry" $ lookup (AnnSpanEntry) (annsDP annIf)
  let anne2' =
        [
          ( AnnKey caseLoc       (CN "HsCase"),   annIf { annsDP = [ (G GHC.AnnCase, ifDelta)
                                                                 , (G GHC.AnnOf,     DP (0,1))]
                                                        } )
        -- , ( AnnKey caseVirtualLoc (CN "(:)"),     Ann (DP (1,newCol)) (ColDelta newCol) (DP (1,newCol)) [] [(DP (1,0))])
        , ( AnnKey trueMatchLoc  (CN "Match"),    Ann (DP (1,2)) [] [] [] Nothing Nothing )
        , ( AnnKey trueLoc1      (CN "ConPatIn"), Ann (DP (0,0)) [] [] [] Nothing Nothing )
        , ( AnnKey trueLoc       (CN "Unqual"),   Ann (DP (0,0)) [] [] [(G GHC.AnnVal, DP (0,0))]  Nothing Nothing)
        , ( AnnKey trueRhsLoc    (CN "GRHS"),     Ann (DP (0,2)) [] [] [(G GHC.AnnRarrow, DP (0,0))]  Nothing Nothing)

        , ( AnnKey falseMatchLoc (CN "Match"),    Ann (DP (1,0)) [] [] []  Nothing Nothing)
        , ( AnnKey falseLoc1     (CN "ConPatIn"), Ann (DP (0,0)) [] [] []  Nothing Nothing)
        , ( AnnKey falseLoc      (CN "Unqual"),   Ann (DP (0,0)) [] [] [(G GHC.AnnVal, DP (0,0))]  Nothing Nothing)
        , ( AnnKey falseRhsLoc   (CN "GRHS"),     Ann (DP (0,1)) [] [] [(G GHC.AnnRarrow, DP (0,0))]  Nothing Nothing)
        ]

  liftT $ putAnnsT (oldAnns `Map.union` (Map.fromList anne2'))
  return ret
ifToCaseTransform x = return x

-- ---------------------------------------------------------------------


-- EOF
