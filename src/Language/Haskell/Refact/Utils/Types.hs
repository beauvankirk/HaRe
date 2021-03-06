{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances    #-}
{-# LANGUAGE CPP    #-}
module Language.Haskell.Refact.Utils.Types
       (
        ApplyRefacResult
       , RefacResult(..)
       -- , TypecheckedModule(..)
       -- , ModuleInfo
       , tmRenamedSource
       , HookIORefData
       -- *
       , TreeId(..)
       , mainTid
       , TokenCache(..)
       , SimpPos
       , SimpSpan
       , NameMap

       ) where

import qualified GHC        as GHC

import Language.Haskell.GHC.ExactPrint

import qualified Data.Map as Map


-- ---------------------------------------------------------------------
-- | The result of a refactoring is the file, a flag as to whether it
-- was modified, and the updated AST
type ApplyRefacResult = ((FilePath, RefacResult), (Anns,GHC.ParsedSource))

data RefacResult = RefacModified | RefacUnmodifed
                 deriving (Show,Ord,Eq)

-- ---------------------------------------------------------------------

tmRenamedSource :: GHC.TypecheckedModule -> GHC.RenamedSource
tmRenamedSource = maybe (error "failed to get renamedSource") id . GHC.tm_renamed_source

-- data TypecheckedModule = TypecheckedModule
--   { tmFileNameUnmapped  :: !FilePath -- ^ Full path of the original file, before
--                                      -- ghc-mod mapping. This may be different
--                                      -- from the one in the ModSummary, if
--                                      -- mapping has taken place.
--   , tmParsedModule      :: !GHC.ParsedModule
--   , tmRenamedSource     :: !GHC.RenamedSource
--   , tmTypecheckedSource :: !GHC.TypecheckedSource
--   , tmMinfExports       :: ![GHC.AvailInfo]
--   , tmMinfRdrEnv        :: !(Maybe GHC.GlobalRdrEnv)   -- Nothing for a compiled/package mod
--   }

-- |Contents of IORef used to communicate with the GHC frontend hook. This has
-- to be kept in the RefactGhc state because so ghc-mod caches GHC sessions, so
-- it is not possible to change the IORef.
type HookIORefData = (FilePath,Maybe GHC.TypecheckedModule)

-- TODO: improve this, or remove it's need
instance Show GHC.TypecheckedModule where
  show _ = "TypeCheckedModule(..)"

-- ---------------------------------------------------------------------

data TreeId = TId !Int deriving (Eq,Ord,Show)

-- |Identifies the tree carrying the main tokens, not any work in
-- progress or deleted ones
mainTid :: TreeId
mainTid = TId 0

data TokenCache a = TK
  { tkCache :: !(Map.Map TreeId a)
  , tkLastTreeId :: !TreeId
  } deriving (Show)

type SimpPos = (Int,Int) -- Line, column
type SimpSpan = (SimpPos,SimpPos)

-- ---------------------------------------------------------------------

type NameMap = Map.Map GHC.SrcSpan GHC.Name

