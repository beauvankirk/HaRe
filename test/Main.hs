{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Monad
-- import TestUtils
import qualified Turtle as Tu
import qualified Control.Foldl as Fold

import Test.Hspec.Runner
import qualified Spec

-- ---------------------------------------------------------------------

main :: IO ()
main = do
  cleanupDirs (Tu.ends "/.stack-work")
  cleanupDirs (Tu.ends "/dist")
  setupStackFiles
  hspec Spec.spec

-- ---------------------------------------------------------------------

setupStackFiles :: IO ()
setupStackFiles =
  forM_ stackFiles $ \f ->
    writeFile f stackFileContents

-- ---------------------------------------------------------------------

stackFiles :: [FilePath]
stackFiles =
  [  "./test/testdata/stack.yaml"
   , "./test/testdata/cabal/cabal3/stack.yaml"
   , "./test/testdata/cabal/foo/stack.yaml"
   , "./test/testdata/cabal/cabal4/stack.yaml"
   , "./test/testdata/cabal/cabal1/stack.yaml"
   , "./test/testdata/cabal/cabal2/stack.yaml"
  ]


-- |Choose a resolver based on the current compiler, otherwise HaRe/ghc-mod will
-- not be able to load the files
resolver :: String
resolver =
#if __GLASGOW_HASKELL__ > 710
  "resolver: nightly-2017-05-23"
#else
  "resolver: lts-6.13"
#endif

-- ---------------------------------------------------------------------

#if __GLASGOW_HASKELL__ < 800
stackFileContents :: String
stackFileContents = unlines
  [ "# WARNING: THIS FILE IS AUTOGENERATED IN test/Main.hs. IT WILL BE OVERWRITTEN ON EVERY TEST RUN"
  , resolver
  , "packages:"
  , "- '.'"
  , "extra-deps: "
  , "- conversion-1.2.1"
  , "- conversion-bytestring-1.0.1"
  , "- conversion-case-insensitive-1.0.0.0"
  , "- conversion-text-1.0.1"
  ]
#else
stackFileContents :: String
stackFileContents = unlines
  [ "# WARNING: THIS FILE IS AUTOGENERATED IN test/Main.hs. IT WILL BE OVERWRITTEN ON EVERY TEST RUN"

  -- Next block from  https://gist.github.com/tfausak/a36862c53a2cc53029cab18a05788b95
  , "compiler: ghc-8.2.0.20170404"
  , "compiler-check: match-exact"
  , "resolver: ghc-8.2.0.20170404"
  , "setup-info:"
  , "  ghc:"
  , "    linux64:"
  , "      8.2.0.20170404:"
  , "        url: https://downloads.haskell.org/~ghc/8.2.1-rc1/ghc-8.2.0.20170404-x86_64-deb8-linux.tar.xz"
  , "        content-length: 138846620"
  , "        sha1: 3fd303b5753b095ce020131405dcf43199e6b447"
  , "    linux64-nopie:"
  , "      8.2.0.20170404:"
  , "        url: https://downloads.haskell.org/~ghc/8.2.1-rc1/ghc-8.2.0.20170404-x86_64-deb8-linux.tar.xz"
  , "        content-length: 138846620"
  , "        sha1: 3fd303b5753b095ce020131405dcf43199e6b447"
  , "    macosx:"
  , "      8.2.0.20170404:"
  , "        url: https://downloads.haskell.org/~ghc/8.2.1-rc1/ghc-8.2.0.20170404-x86_64-apple-darwin.tar.xz"
  , "        content-length: 124010408"
  , "        sha1: 301de7f5b6ed87ade2182ed2552df2ef39b98b03"
  , "    # The Windows build is broken :("
  , "    # https://www.reddit.com/r/haskell/comments/64he68/announce_ghc_821_release_candidate_1/dg2b5ei/"
  , "    windows64:"
  , "      8.2.0.20170404:"
  , "        url: https://downloads.haskell.org/~ghc/8.2.1-rc1/ghc-8.2.0.20170404-x86_64-unknown-mingw32.tar.xz"
  , "        content-length: 173924808"
  , "        sha1: 5cfd11230ff95423a7b19104232247e3fab0dba3"

  , "allow-newer: true"

  , "packages:"
  , "- '.'"
  , "- location:"
  , "    git: https://github.com/alanz/syb.git"
  , "    commit: 39f0c153ab208b6066fd5f34f80f85001627ae48"
  , "  extra-dep: true"
  , "extra-deps: "
  , "- conversion-1.2.1"
  , "- conversion-bytestring-1.0.1"
  , "- conversion-case-insensitive-1.0.0.0"
  , "- conversion-text-1.0.1"
  , "- attoparsec-0.13.1.0"
  , "- base-prelude-1.2.0.1"
  , "- bytestring-0.10.8.1"
  , "- case-insensitive-1.2.0.9"
  , "- parsec-3.1.11"
  , "- text-1.2.2.1"
  , "- binary-0.9.0.0"
  , "- containers-0.5.10.2"
  , "- hashable-1.2.6.0"
  , "- mtl-2.2.1"
  , "- scientific-0.3.4.12"
  , "- integer-logarithms-1.0.1"
  , "- vector-0.12.0.1"
  , "- primitive-0.6.2.0"
  ]
#endif

-- ---------------------------------------------------------------------

cleanupDirs :: Tu.Pattern t -> IO ()
cleanupDirs ending = do
  dirs <- getDirs ending
  forM_ dirs  $ \dir -> Tu.rmtree dir

getDirs :: Tu.Pattern t -> IO [Tu.FilePath]
getDirs ending = do
  let
    -- dirs = Tu.find (Tu.ends "/.stack-work") "./test"
    dirs = Tu.find ending "./test"
  Tu.fold dirs Fold.list

listStackDirs :: IO ()
listStackDirs = Tu.sh $ do
  dirs <- Tu.find (Tu.ends "/.stack-work") "./test"
  mapM Tu.echo $ Tu.textToLines $ "found:" Tu.<> (Tu.repr dirs)

