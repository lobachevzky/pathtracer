{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TupleSections #-}

module Lib
  ( raysFromCam
  , traceCanvas
  , bounceRay
  , reflectVector
  , specular
  ) where

import qualified Codec.Picture as P
import Control.Monad
import Data.Angle (Degrees(..), arccosine)
import Data.Array.Repa
       ((:.)(..), Array, D, DIM3, DIM1, DIM2, U, Z(..), (!), (+^))
import qualified Data.Array.Repa as R
import qualified Data.Vector as V
import Object
       (Object(..), Ray(..), Point(..), Vector(..), getColor, getNormal,
        distanceFrom, objects, march, getVector)
import qualified Params
import qualified System.Random as Random
import Triple (Triple(..), Vec3, normalize, dot)
import Util
       (flatten, white, black, rotateRel, randomRangeList,
        fromTripleArray)

raysFromCam :: Int -> Array D DIM1 Ray
raysFromCam iteration =
  flatten $
  R.fromFunction
    (Z :. Params.imgHeight :. Params.imgWidth)
    (rayFromCamToPixel iteration)

rayFromCamToPixel :: Int -> DIM2 -> Ray
rayFromCamToPixel iteration (Z :. i :. j) =
  Ray
  { _origin = Point $ pure 0
  , _vector = Vector $ normalize $ Triple i' j' Params.cameraDepth
  , _gen = Random.mkStdGen seed
  , _lastStruck = Nothing
  }
  where
    i' = fromIntegral Params.imgHeight / 2 - fromIntegral i
    j' = fromIntegral j - fromIntegral Params.imgWidth / 2
    seed =
      (iteration * Params.imgHeight * Params.imgWidth) +
      (i * Params.imgWidth + j)

traceCanvas :: Int
            -> Array D DIM1 (Triple Double)
            -> Array D DIM1 (Triple Double)
traceCanvas iteration canvas = canvas +^ newColor
  where
    newColor =
      R.map (terminalColor Params.maxBounces white) (raysFromCam iteration)

---
terminalColor :: Int -> Triple Double -> Ray -> Triple Double
terminalColor 0 _ _ = black -- ran out of bounces
terminalColor bouncesLeft pixel ray = interactWith $ closestObjectTo ray
  where
    interactWith :: Maybe (Object, Double) -> Vec3
    interactWith Nothing = black -- pixel
    interactWith (Just (object, distance))
      | hitLight = (_emittance object *) <$> pixel
      | otherwise = terminalColor (bouncesLeft - 1) pixel' ray'
      where
        hitLight = _emittance object > 0 :: Bool
        ray' = bounceRay ray object distance :: Ray
        pixel' = pixel * getColor object :: Triple Double

closestObjectTo :: Ray -> Maybe (Object, Double)
closestObjectTo ray = do
  guard . not $ V.null pairs -- not all Nothing
  return $ V.minimumBy distanceOrdering pairs
  where
    pairs :: V.Vector (Object, Double)
    -- Drop objects with negative and infinite distances
    pairs = V.mapMaybe pairWithDistance objectsWithoutLastStruck
    pairWithDistance :: Object -> Maybe (Object, Double)
    -- Nothing if distance is negative or infinite
    pairWithDistance object = (object, ) <$> (distanceFrom ray $ _form object)
    objectsWithoutLastStruck :: V.Vector Object
    objectsWithoutLastStruck =
      case _lastStruck ray of
        Nothing -> objects
        Just lastStruck -> V.filter (lastStruck /=) objects
    distanceOrdering :: (Object, Double) -> (Object, Double) -> Ordering
    distanceOrdering (_, distance1) (_, distance2) = compare distance1 distance2

---
bounceRay :: Ray -> Object -> Double -> Ray
bounceRay ray@(Ray {_gen = gen}) object distance =
  Ray origin vector gen' $ Just object
  where
    origin = Point $ march ray distance
    vector = Vector $ reflectVector gen object $ getVector ray
    (_, gen') = Random.random gen :: (Int, Random.StdGen)

reflectVector :: Random.StdGen -> Object -> Triple Double -> Triple Double
reflectVector gen object vector
  | _reflective object = specular gen 0 vector normal
  | otherwise = diffuse gen vector normal
  where
    normal = getNormal $ _form object

specular :: Random.StdGen
         -> Double
         -> Triple Double
         -> Triple Double
         -> Triple Double
specular gen noise vector normal =
  rotateRel (Degrees theta) (Degrees phi) vector'
  where
    normal' = normalize normal
    projection = (vector `dot` normal' *) <$> normal'
    vector' = vector + (-2) * projection
        -- here we offset the angle of reflection by `noise` but ensure that this does not
        -- cause rays to penetrate the surface of the object
    angleWithSurface =
      (Degrees 90) - (arccosine . abs $ normal' `dot` normalize vector)
    Degrees maxTheta = min angleWithSurface $ Degrees noise
    ([theta, phi], _) = randomRangeList gen [(0, maxTheta), (0, 380)]

diffuse :: Random.StdGen -> Triple Double -> Triple Double -> Triple Double
diffuse gen _ normal = rotateRel (Degrees theta) (Degrees phi) normal
  where
    ([theta, phi], _) = randomRangeList gen [(0, 90), (0, 380)]
