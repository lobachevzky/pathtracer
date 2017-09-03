{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeOperators #-}

module Main
  ( main
  , Vec3
  ) where

import qualified Codec.Picture as P
import qualified Data.Array.Repa as R

import Conversion (repa3ToImage)
import Data.Array.Repa
       ((:.)(..), Array, D, DIM1, DIM2, U, Z(..), (!))
import Lib (traceCanvas, startingValues)
import qualified Params
import Triple (Vec3, Triple(..))
import Util (black, flatten, reshape, fromTripleArray)

main :: IO ()
main = do
  let (canvasDim3M, _) = iterate traceCanvas startingValues !! Params.numIters
  canvasDim3 <- canvasDim3M
  (P.savePngImage "image.png" . P.ImageRGB8 . repa3ToImage) canvasDim3
