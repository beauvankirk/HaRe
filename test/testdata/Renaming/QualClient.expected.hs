module Main where

{- foo is imported qualified as in QualClient. Renaming should
   preserve the qualification there
-}

import qualified Renaming.QualServer as QS

baz :: String
baz = QS.foo1 : "hello"

main = putStrLn "hello"
