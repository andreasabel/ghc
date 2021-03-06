{-# LANGUAGE Trustworthy #-}
{-# LANGUAGE NoImplicitPrelude #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  Control.Monad
-- Copyright   :  (c) The University of Glasgow 2001
-- License     :  BSD-style (see the file libraries/base/LICENSE)
--
-- Maintainer  :  libraries@haskell.org
-- Stability   :  provisional
-- Portability :  portable
--
-- The 'Functor', 'Monad' and 'MonadPlus' classes,
-- with some useful operations on monads.

module Control.Monad
    (
    -- * Functor and monad classes

      Functor(fmap)
    , Monad((>>=), (>>), return, fail)
    , Alternative(empty, (<|>), some, many)
    , MonadPlus(mzero, mplus)
    -- * Functions

    -- ** Naming conventions
    -- $naming

    -- ** Basic @Monad@ functions

    , mapM
    , mapM_
    , forM
    , forM_
    , sequence
    , sequence_
    , (=<<)
    , (>=>)
    , (<=<)
    , forever
    , void

    -- ** Generalisations of list functions

    , join
    , msum
    , mfilter
    , filterM
    , mapAndUnzipM
    , zipWithM
    , zipWithM_
    , foldM
    , foldM_
    , replicateM
    , replicateM_

    -- ** Conditional execution of monadic expressions

    , guard
    , when
    , unless

    -- ** Monadic lifting operators

    , liftM
    , liftM2
    , liftM3
    , liftM4
    , liftM5

    , ap

    -- ** Strict monadic functions

    , (<$!>)
    ) where

import Data.Maybe

import GHC.List
import GHC.Base

infixr 1 =<<
infixl 3 <|>

-- -----------------------------------------------------------------------------
-- Prelude monad functions

-- | Same as '>>=', but with the arguments interchanged.
{-# SPECIALISE (=<<) :: (a -> [b]) -> [a] -> [b] #-}
(=<<)           :: Monad m => (a -> m b) -> m a -> m b
f =<< x         = x >>= f

-- | Evaluate each action in the sequence from left to right,
-- and collect the results.
sequence       :: Monad m => [m a] -> m [a] 
{-# INLINE sequence #-}
sequence ms = foldr k (return []) ms
            where
              k m m' = do { x <- m; xs <- m'; return (x:xs) }

-- | Evaluate each action in the sequence from left to right,
-- and ignore the results.
sequence_        :: Monad m => [m a] -> m ()
{-# INLINE sequence_ #-}
sequence_ ms     =  foldr (>>) (return ()) ms

-- | @'mapM' f@ is equivalent to @'sequence' . 'map' f@.
mapM            :: Monad m => (a -> m b) -> [a] -> m [b]
{-# INLINE mapM #-}
mapM f as       =  sequence (map f as)

-- | @'mapM_' f@ is equivalent to @'sequence_' . 'map' f@.
mapM_           :: Monad m => (a -> m b) -> [a] -> m ()
{-# INLINE mapM_ #-}
mapM_ f as      =  sequence_ (map f as)

-- -----------------------------------------------------------------------------
-- The Alternative class definition

-- | A monoid on applicative functors.
--
-- Minimal complete definition: 'empty' and '<|>'.
--
-- If defined, 'some' and 'many' should be the least solutions
-- of the equations:
--
-- * @some v = (:) '<$>' v '<*>' many v@
--
-- * @many v = some v '<|>' 'pure' []@
class Applicative f => Alternative f where
    -- | The identity of '<|>'
    empty :: f a
    -- | An associative binary operation
    (<|>) :: f a -> f a -> f a

    -- | One or more.
    some :: f a -> f [a]
    some v = some_v
      where
        many_v = some_v <|> pure []
        some_v = (fmap (:) v) <*> many_v

    -- | Zero or more.
    many :: f a -> f [a]
    many v = many_v
      where
        many_v = some_v <|> pure []
        some_v = (fmap (:) v) <*> many_v

instance Alternative Maybe where
    empty = Nothing
    Nothing <|> r = r
    l       <|> _ = l

instance Alternative [] where
    empty = []
    (<|>) = (++)


-- -----------------------------------------------------------------------------
-- The MonadPlus class definition

-- | Monads that also support choice and failure.
class (Alternative m, Monad m) => MonadPlus m where
   -- | the identity of 'mplus'.  It should also satisfy the equations
   --
   -- > mzero >>= f  =  mzero
   -- > v >> mzero   =  mzero
   --
   mzero :: m a
   mzero = empty

   -- | an associative operation
   mplus :: m a -> m a -> m a
   mplus = (<|>)

instance MonadPlus [] where
   mzero = []
   mplus = (++)

instance MonadPlus Maybe where
   mzero = Nothing

   Nothing `mplus` ys  = ys
   xs      `mplus` _ys = xs

-- -----------------------------------------------------------------------------
-- Functions mandated by the Prelude

-- | @'guard' b@ is @'return' ()@ if @b@ is 'True',
-- and 'mzero' if @b@ is 'False'.
guard           :: (MonadPlus m) => Bool -> m ()
guard True      =  return ()
guard False     =  mzero

-- | This generalizes the list-based 'filter' function.

filterM          :: (Monad m) => (a -> m Bool) -> [a] -> m [a]
filterM _ []     =  return []
filterM p (x:xs) =  do
   flg <- p x
   ys  <- filterM p xs
   return (if flg then x:ys else ys)

-- | 'forM' is 'mapM' with its arguments flipped
forM            :: Monad m => [a] -> (a -> m b) -> m [b]
{-# INLINE forM #-}
forM            = flip mapM

-- | 'forM_' is 'mapM_' with its arguments flipped
forM_           :: Monad m => [a] -> (a -> m b) -> m ()
{-# INLINE forM_ #-}
forM_           = flip mapM_

-- | This generalizes the list-based 'concat' function.

msum        :: MonadPlus m => [m a] -> m a
{-# INLINE msum #-}
msum        =  foldr mplus mzero

infixr 1 <=<, >=>

-- | Left-to-right Kleisli composition of monads.
(>=>)       :: Monad m => (a -> m b) -> (b -> m c) -> (a -> m c)
f >=> g     = \x -> f x >>= g

-- | Right-to-left Kleisli composition of monads. @('>=>')@, with the arguments flipped
(<=<)       :: Monad m => (b -> m c) -> (a -> m b) -> (a -> m c)
(<=<)       = flip (>=>)

-- | @'forever' act@ repeats the action infinitely.
forever     :: (Monad m) => m a -> m b
{-# INLINE forever #-}
forever a   = let a' = a >> a' in a'
-- Use explicit sharing here, as it is prevents a space leak regardless of
-- optimizations.

-- | @'void' value@ discards or ignores the result of evaluation, such as the return value of an 'IO' action.
void :: Functor f => f a -> f ()
void = fmap (const ())

-- -----------------------------------------------------------------------------
-- Other monad functions

-- | The 'mapAndUnzipM' function maps its first argument over a list, returning
-- the result as a pair of lists. This function is mainly used with complicated
-- data structures or a state-transforming monad.
mapAndUnzipM      :: (Monad m) => (a -> m (b,c)) -> [a] -> m ([b], [c])
{-# INLINE mapAndUnzipM #-}
mapAndUnzipM f xs =  sequence (map f xs) >>= return . unzip

-- | The 'zipWithM' function generalizes 'zipWith' to arbitrary monads.
zipWithM          :: (Monad m) => (a -> b -> m c) -> [a] -> [b] -> m [c]
{-# INLINE zipWithM #-}
zipWithM f xs ys  =  sequence (zipWith f xs ys)

-- | 'zipWithM_' is the extension of 'zipWithM' which ignores the final result.
zipWithM_         :: (Monad m) => (a -> b -> m c) -> [a] -> [b] -> m ()
{-# INLINE zipWithM_ #-}
zipWithM_ f xs ys =  sequence_ (zipWith f xs ys)

{- | The 'foldM' function is analogous to 'foldl', except that its result is
encapsulated in a monad. Note that 'foldM' works from left-to-right over
the list arguments. This could be an issue where @('>>')@ and the `folded
function' are not commutative.


>       foldM f a1 [x1, x2, ..., xm]

==  

>       do
>         a2 <- f a1 x1
>         a3 <- f a2 x2
>         ...
>         f am xm

If right-to-left evaluation is required, the input list should be reversed.
-}

foldM             :: (Monad m) => (a -> b -> m a) -> a -> [b] -> m a
{-# INLINEABLE foldM #-}
{-# SPECIALISE foldM :: (a -> b -> IO a) -> a -> [b] -> IO a #-}
{-# SPECIALISE foldM :: (a -> b -> Maybe a) -> a -> [b] -> Maybe a #-}
foldM _ a []      =  return a
foldM f a (x:xs)  =  f a x >>= \fax -> foldM f fax xs

-- | Like 'foldM', but discards the result.
foldM_            :: (Monad m) => (a -> b -> m a) -> a -> [b] -> m ()
{-# INLINEABLE foldM_ #-}
{-# SPECIALISE foldM_ :: (a -> b -> IO a) -> a -> [b] -> IO () #-}
{-# SPECIALISE foldM_ :: (a -> b -> Maybe a) -> a -> [b] -> Maybe () #-}
foldM_ f a xs     = foldM f a xs >> return ()

-- | @'replicateM' n act@ performs the action @n@ times,
-- gathering the results.
replicateM        :: (Monad m) => Int -> m a -> m [a]
{-# INLINEABLE replicateM #-}
{-# SPECIALISE replicateM :: Int -> IO a -> IO [a] #-}
{-# SPECIALISE replicateM :: Int -> Maybe a -> Maybe [a] #-}
replicateM n x    = sequence (replicate n x)

-- | Like 'replicateM', but discards the result.
replicateM_       :: (Monad m) => Int -> m a -> m ()
{-# INLINEABLE replicateM_ #-}
{-# SPECIALISE replicateM_ :: Int -> IO a -> IO () #-}
{-# SPECIALISE replicateM_ :: Int -> Maybe a -> Maybe () #-}
replicateM_ n x   = sequence_ (replicate n x)

{- | Conditional execution of monadic expressions. For example, 

>       when debug (putStr "Debugging\n")

will output the string @Debugging\\n@ if the Boolean value @debug@ is 'True',
and otherwise do nothing.
-}

when              :: (Monad m) => Bool -> m () -> m ()
{-# INLINEABLE when #-}
{-# SPECIALISE when :: Bool -> IO () -> IO () #-}
{-# SPECIALISE when :: Bool -> Maybe () -> Maybe () #-}
when p s          =  if p then s else return ()

-- | The reverse of 'when'.

unless            :: (Monad m) => Bool -> m () -> m ()
{-# INLINEABLE unless #-}
{-# SPECIALISE unless :: Bool -> IO () -> IO () #-}
{-# SPECIALISE unless :: Bool -> Maybe () -> Maybe () #-}
unless p s        =  if p then return () else s

infixl 4 <$!>

-- | Strict version of 'Data.Functor.<$>'.
--
-- /Since: 4.8.0.0/
(<$!>) :: Monad m => (a -> b) -> m a -> m b
{-# INLINE (<$!>) #-}
f <$!> m = do
  x <- m
  let z = f x
  z `seq` return z


-- -----------------------------------------------------------------------------
-- Other MonadPlus functions

-- | Direct 'MonadPlus' equivalent of 'filter'
-- @'filter'@ = @(mfilter:: (a -> Bool) -> [a] -> [a]@
-- applicable to any 'MonadPlus', for example
-- @mfilter odd (Just 1) == Just 1@
-- @mfilter odd (Just 2) == Nothing@

mfilter :: (MonadPlus m) => (a -> Bool) -> m a -> m a
{-# INLINEABLE mfilter #-}
mfilter p ma = do
  a <- ma
  if p a then return a else mzero

{- $naming

The functions in this library use the following naming conventions: 

* A postfix \'@M@\' always stands for a function in the Kleisli category:
  The monad type constructor @m@ is added to function results
  (modulo currying) and nowhere else.  So, for example, 

>  filter  ::              (a ->   Bool) -> [a] ->   [a]
>  filterM :: (Monad m) => (a -> m Bool) -> [a] -> m [a]

* A postfix \'@_@\' changes the result type from @(m a)@ to @(m ())@.
  Thus, for example: 

>  sequence  :: Monad m => [m a] -> m [a] 
>  sequence_ :: Monad m => [m a] -> m () 

* A prefix \'@m@\' generalizes an existing function to a monadic form.
  Thus, for example: 

>  sum  :: Num a       => [a]   -> a
>  msum :: MonadPlus m => [m a] -> m a

-}
