{-# LANGUAGE ScopedTypeVariables #-}
module HList3 where

--Super contrived example
explode :: Int -> [a] -> [a]
explode n lst = concat (map (\x -> replicate n x) lst)

f :: IO ()
f = do
  (lst :: [Int]) <- read <$> getLine
  let newLst = explode 3 lst
  print newLst