{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE CPP #-}

-- | This is a legacy module from the pre-GHC HaRe, and will disappear
-- eventually.

module Language.Haskell.Refact.Utils.TypeSyn where


-- Modules from GHC
import qualified GHC        as GHC
import qualified Name       as GHC
import qualified Outputable as GHC
-- import Language.Haskell.Refact.Utils.Types
import Language.Haskell.GHC.ExactPrint.Types

-- ---------------------------------------------------------------------

type HsExpP    = GHC.HsExpr GhcPs
type HsPatP    = GHC.Pat GhcPs
type HsDeclP   = GHC.LHsDecl GhcPs

type HsDeclsP = GHC.HsGroup GHC.Name

type InScopes = [GHC.Name]

type Export = GHC.LIE GhcPs

-- ---------------------------------------------------------------------
-- From old/tools/base/defs/PNT.hs

-- | HsName is a name as it is found in the source
-- This seems to be quite a close correlation
type HsName = GHC.RdrName

-- |The PN is the name as it occurs to the parser, and
-- corresponds with the GHC.RdrName
-- type PN     = GHC.RdrName
newtype PName = PN HsName deriving (Eq)

-- | The PNT is the unique name, after GHC renaming. It corresponds to
-- GHC.Name data PNT = PNT GHC.Name deriving (Data,Typeable) -- Note:
-- GHC.Name has SrcLoc in it already

instance Show GHC.NameSpace where
  show ns
    | ns == GHC.tcName   = "TcClsName"
    | ns == GHC.dataName = "DataName"
    | ns == GHC.varName  = "VarName"
    | ns == GHC.tvName   = "TvName"
    | otherwise          = "UnknownNamespace"

instance GHC.Outputable GHC.NameSpace where
  ppr x = GHC.text $ show x


#if __GLASGOW_HASKELL__ <= 800
instance GHC.Outputable (GHC.MatchGroup GhcRn (GHC.LHsExpr GhcRn)) where
  ppr (GHC.MG ms _ _ _) = GHC.text "MatchGroup" GHC.<+> GHC.ppr ms

instance GHC.Outputable (GHC.Match GhcRn (GHC.LHsExpr GhcRn)) where
  ppr (GHC.Match _fn pats mtyp grhs) = GHC.text "Match" GHC.<+> GHC.ppr pats
                                                    GHC.<+> GHC.ppr mtyp
                                                    GHC.<+> GHC.ppr grhs
#endif

instance GHC.Outputable (GHC.GRHSs GhcRn (GHC.LHsExpr GhcRn)) where
#if __GLASGOW_HASKELL__ >= 806
  ppr (GHC.GRHSs _ grhss binds) = GHC.text "GRHSs" GHC.<+> GHC.ppr grhss
#else
  ppr (GHC.GRHSs   grhss binds) = GHC.text "GRHSs" GHC.<+> GHC.ppr grhss
#endif
                                                   GHC.<+> GHC.ppr binds


instance GHC.Outputable (GHC.GRHS GhcRn (GHC.LHsExpr GhcRn)) where
#if __GLASGOW_HASKELL__ >= 806
  ppr (GHC.GRHS _ guards rhs) = GHC.text "GRHS" GHC.<+> GHC.ppr guards
#else
  ppr (GHC.GRHS   guards rhs) = GHC.text "GRHS" GHC.<+> GHC.ppr guards
#endif
                                                GHC.<+> GHC.ppr rhs


instance GHC.Outputable (GHC.HsTupArg GhcRn) where
#if __GLASGOW_HASKELL__ >= 806
  ppr (GHC.Present _ e)    = GHC.text "Present" GHC.<+> GHC.ppr e
#else
  ppr (GHC.Present   e)    = GHC.text "Present" GHC.<+> GHC.ppr e
#endif
  ppr (GHC.Missing _typ) = GHC.text "Missing"


#if !(defined(MIN_VERSION_GLASGOW_HASKELL) && (MIN_VERSION_GLASGOW_HASKELL(8,0,1,1)))
instance GHC.Outputable (GHC.ConDeclField GhcRn) where
  ppr (GHC.ConDeclField name typ doc) = GHC.text "ConDeclField"
                                          GHC.<+> GHC.ppr name
                                          GHC.<+> GHC.ppr typ
                                          GHC.<+> GHC.ppr doc
#endif

#if __GLASGOW_HASKELL__ <= 710
instance GHC.Outputable (GHC.TyFamEqn GhcRn (GHC.LHsTyVarBndrs GhcRn)) where
  ppr (GHC.TyFamEqn name pats rhs) = GHC.text "TyFamEqn"
                                          GHC.<+> GHC.ppr name
                                          GHC.<+> GHC.ppr pats
                                          GHC.<+> GHC.ppr rhs
#endif

-- ---------------------------------------------------------------------
