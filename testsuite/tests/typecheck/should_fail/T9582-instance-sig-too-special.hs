-- 2014-09-18 Andreas Abel
-- Failing test case for ticket 9582

{-# LANGUAGE InstanceSigs, TypeFamilies #-}

module Fail where

class C a where
  type T a
  m :: T a

instance C [a] where
  type T [a] = [a]

  -- The following type signature for m should be invalid.
  -- We asked for something of a more general type.
  m :: String
  m = "bla"
