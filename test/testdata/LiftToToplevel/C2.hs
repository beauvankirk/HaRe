module LiftToToplevel.C2 (module LiftToToplevel.D2, module LiftToToplevel.C2) where 

import LiftToToplevel.D2

anotherFun (x:xs) =  x^4 + anotherFun xs

anotherFun [] = 0



