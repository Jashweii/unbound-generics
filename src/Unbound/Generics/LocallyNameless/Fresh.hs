-- |
-- Module     : Unbound.Generics.LocallyNameless.Fresh
-- Copyright  : (c) 2014, Aleksey Kliger
-- License    : BSD3 (See LICENSE)
-- Maintainer : Aleksey Kliger
-- Stability  : experimental
--
-- Global and local freshness monads.
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module Unbound.Generics.LocallyNameless.Fresh where

import Control.Applicative (Applicative)
import Control.Monad (MonadPlus)
import Control.Monad.Fix (MonadFix)

import Control.Monad.Trans
import Control.Monad.Trans.Error
import Control.Monad.Trans.Maybe
import Control.Monad.Trans.Reader
import Control.Monad.Trans.State.Lazy as Lazy
import Control.Monad.Trans.State.Strict as Strict
import Control.Monad.Trans.Writer.Lazy as Lazy
import Control.Monad.Trans.Writer.Strict as Strict

import Data.Monoid (Monoid)

import qualified Control.Monad.State as St

import Unbound.Generics.LocallyNameless.Name

-- | The @Fresh@ type class governs monads which can generate new
--   globally unique 'Name's based on a given 'Name'.
class Monad m => Fresh m where

  -- | Generate a new globally unique name based on the given one.
  fresh :: Name a -> m (Name a)


-- | The @FreshM@ monad transformer.  Keeps track of the lowest index
--   still globally unused, and increments the index every time it is
--   asked for a fresh name.
newtype FreshMT m a = FreshMT { unFreshMT :: St.StateT Integer m a }
  deriving (Functor, Applicative, Monad, MonadPlus, MonadIO, MonadFix)

-- | Run a 'FreshMT' computation (with the global index starting at zero).
runFreshMT :: Monad m => FreshMT m a -> m a
runFreshMT m = contFreshMT m 0

-- | Run a 'FreshMT' computation given a starting index for fresh name
--   generation.
contFreshMT :: Monad m => FreshMT m a -> Integer -> m a
contFreshMT (FreshMT m) = St.evalStateT m

instance Monad m => Fresh (FreshMT m) where
  fresh (Fn s _) = FreshMT $ do
    n <- St.get
    St.put $! n + 1
    return $ (Fn s n)
  fresh nm@(Bn {}) = return nm

instance (Error e, Fresh m) => Fresh (ErrorT e m) where
  fresh = lift . fresh

instance Fresh m => Fresh (MaybeT m) where
  fresh = lift . fresh

instance Fresh m => Fresh (ReaderT r m) where
  fresh = lift . fresh

instance Fresh m => Fresh (Lazy.StateT s m) where
  fresh = lift . fresh

instance Fresh m => Fresh (Strict.StateT s m) where
  fresh = lift . fresh

instance (Monoid w, Fresh m) => Fresh (Lazy.WriterT w m) where
  fresh = lift . fresh

instance (Monoid w, Fresh m) => Fresh (Strict.WriterT w m) where
  fresh = lift . fresh

instance MonadTrans FreshMT where
  lift = FreshMT . lift