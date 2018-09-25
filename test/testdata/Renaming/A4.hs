module Main where

import Renaming.B4
import Renaming.C4
import Renaming.D4

maim :: Tree Int ->Bool
maim t = isSame (sumSquares (fringe t))
               (sumSquares (Renaming.B4.myFringe t)+sumSquares (Renaming.C4.myFringe t))

main = putStrLn "hello"
