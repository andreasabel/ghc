-- 2014-09-18 Andreas Abel
-- Failing test case for ticket 9582

{-# LANGUAGE InstanceSigs, TypeFamilies #-}

module Fail where

class C a where
  type T a
  m :: T a

instance C Int where
  type T Int = String

  -- The following type signature for m is currently rejected,
  -- as it is too general.
  m :: Show a => [a]
  m = []

  -- However, in principle we could allow method instances of
  -- a more general type than expected, and insert a coercion
  -- back to the more specialized, expected type.
