-- 2014-09-18 Andreas Abel
-- Test case for ticket 9582

{-# LANGUAGE InstanceSigs, TypeFamilies #-}

class C a where
  type T a
  m :: T a

instance C Int where
  type T Int = String

  -- The following type signature for m should be valid.
  m :: String
  m = "bla"

-- Error WAS:
-- Method signature does not match class; it should be m :: T Int
--    In the instance declaration for ‘C Int’

main :: IO ()
main = return ()
