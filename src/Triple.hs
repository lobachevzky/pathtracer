module Triple
  ( Triple(..)
  , Vec3
  , dot
  , cross
  , norm2
  , normalize
  , tupleToTriple
  , tripleToTuple
  , tripleToList
  , listToTriple
  , tSum
  , tAnd
  ) where

import Control.Applicative
import Test.QuickCheck (Arbitrary, arbitrary)

data Triple a =
  Triple a
         a
         a

type Vec3 = Triple Double

tupleToTriple :: (t, t, t) -> Triple t
tupleToTriple (x, y, z) = Triple x y z

tripleToTuple :: Triple t -> (t, t, t)
tripleToTuple (Triple x y z) = (x, y, z)

tripleToList :: Triple t -> [t]
tripleToList (Triple a1 a2 a3) = [a1, a2, a3]

listToTriple :: [t] -> Triple t
listToTriple [a1, a2, a3] = Triple a1 a2 a3
listToTriple _ = error "Not a valid type to convert to Triple."

tSum
  :: Num a
  => Triple a -> a
tSum = sum . tripleToList

tAnd :: Triple Bool -> Bool
tAnd = and . tripleToList

dot
  :: Num a
  => Triple a -> Triple a -> a
dot a b = tSum $ a * b

cross
  :: Num a
  => Triple a -> Triple a -> Triple a
cross (Triple x1 y1 z1) (Triple x2 y2 z2) = Triple x y z
  where
    x = y1 * z2 - z1 * y2
    y = z1 * x2 - x1 * z2
    z = x1 * y2 - y1 * x2

norm2
  :: Floating a
  => Triple a -> a
norm2 (Triple x y z) = sqrt $ x ^ 2 + y ^ 2 + z ^ 2

normalize :: Vec3 -> Vec3
normalize vector = (/ norm) <$> vector
  where
    norm = max (10 ** (-6)) $ norm2 vector

instance Show a =>
         Show (Triple a) where
  show = show . tripleToTuple

instance Functor Triple where
  fmap f (Triple a1 a2 a3) = Triple (f a1) (f a2) (f a3)

instance Applicative Triple where
  pure a = Triple a a a
  Triple f1 f2 f3 <*> Triple a1 a2 a3 = Triple (f1 a1) (f2 a2) (f3 a3)

instance Eq a =>
         Eq (Triple a) where
  t1 == t2 = tAnd $ liftA2 (==) t1 t2

instance Num a =>
         Num (Triple a) where
  (+) = liftA2 (+)
  (*) = liftA2 (*)
  abs = fmap abs
  signum = fmap signum
  fromInteger = fmap fromInteger . pure
  negate = fmap negate

instance Fractional a =>
         Fractional (Triple a) where
  fromRational = fmap fromRational . pure
  (/) = liftA2 (/)

instance Arbitrary a =>
         Arbitrary (Triple a) where
  arbitrary = do
    a1 <- arbitrary
    a2 <- arbitrary
    a3 <- arbitrary
    return $ Triple a1 a2 a3
