{-# LANGUAGE DataKinds #-}
{-# LANGUAGE Safe #-}
-- |
-- Module       : Data.Text.Lazy.Encoding.Base64.URL
-- Copyright    : (c) 2019-2022 Emily Pillmore
-- License      : BSD-style
--
-- Maintainer   : Emily Pillmore <emilypi@cohomolo.gy>
-- Stability    : stable
-- Portability  : non-portable
--
-- This module contains 'Data.Text.Lazy.Text'-valued combinators for
-- implementing the RFC 4648 specification of the Base64url
-- encoding format. This includes strictly padded/unpadded and lenient decoding
-- variants, as well as internal and external validation for canonicity.
--
module Data.Text.Lazy.Encoding.Base64.URL
( -- * Encoding
  encodeBase64
, encodeBase64Unpadded
  -- * Decoding
, decodeBase64
, decodeBase64With
, decodeBase64Unpadded
, decodeBase64UnpaddedWith
, decodeBase64Padded
, decodeBase64PaddedWith
, decodeBase64Lenient
  -- * Validation
, isBase64Url
, isValidBase64Url
) where

import Data.Base64.Types

import Data.Bifunctor (first)
import Data.ByteString.Lazy (ByteString)
import qualified Data.ByteString.Lazy.Base64.URL as BL64U

import qualified Data.Text as T
import Data.Text.Encoding.Base64.Error
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Encoding as TL

-- | Encode a 'TL.Text' value in Base64url with padding.
--
-- See: <https://tools.ietf.org/html/rfc4648#section-5 RFC-4648 section 5>
--
-- === __Examples__:
--
-- >>> encodeBase64 "<<?>>"
-- "PDw_Pj4="
--
encodeBase64 :: TL.Text -> Base64 'UrlPadded TL.Text
encodeBase64 = BL64U.encodeBase64 . TL.encodeUtf8
{-# INLINE encodeBase64 #-}

-- | Decode a padded Base64url-encoded 'TL.Text' value. If its length is not a multiple
-- of 4, then padding chars will be added to fill out the input to a multiple of
-- 4 for safe decoding as base64url encodings are optionally padded.
--
-- For a decoder that fails on unpadded input, use 'decodeBase64Unpadded'.
--
-- /Note:/ This function makes sure that decoding is total by deferring to
-- 'T.decodeLatin1'. This will always round trip for any valid Base64-encoded
-- text value, but it may not round trip for bad inputs. The onus is on the
-- caller to make sure inputs are valid. If unsure, defer to `decodeBase64With`
-- and pass in a custom decode function.
--
-- See: <https://tools.ietf.org/html/rfc4648#section-4 RFC-4648 section 4>
--
-- === __Examples__:
--
-- >>> decodeBase64 "PDw_Pj4="
-- Right "<<?>>"
--
-- >>> decodeBase64 "PDw_Pj4"
-- Right "<<?>>"
--
-- >>> decodeBase64 "PDw-Pg="
-- Left "Base64-encoded bytestring has invalid padding"
--
-- >>> decodeBase64 "PDw-Pg"
-- Right "<<>>"
--
decodeBase64 :: UrlAlphabet k => Base64 k TL.Text -> Either T.Text TL.Text
decodeBase64 = fmap TL.decodeLatin1 . BL64U.decodeBase64 . fmap TL.encodeUtf8
{-# INLINE decodeBase64 #-}

-- | Attempt to decode a lazy 'ByteString' value as Base64url, converting from
-- 'ByteString' to 'TL.Text' according to some encoding function. In practice,
-- This is something like 'decodeUtf8'', which may produce an error.
--
-- See: <https://tools.ietf.org/html/rfc4648#section-4 RFC-4648 section 4>
--
-- === __Examples__:
--
-- @
-- 'decodeBase64With' 'TL.decodeUtf8''
--   :: 'ByteString' -> 'Either' ('Base64Error' 'UnicodeException') 'TL.Text'
-- @
--
decodeBase64With
    :: UrlAlphabet k
    => (ByteString -> Either err TL.Text)
      -- ^ convert a bytestring to text (e.g. 'TL.decodeUtf8'')
    -> Base64 k ByteString
      -- ^ Input text to decode
    -> Either (Base64Error err) TL.Text
decodeBase64With f t = case BL64U.decodeBase64 t of
  Left de -> Left $ DecodeError de
  Right a -> first ConversionError (f a)
{-# INLINE decodeBase64With #-}

-- | Encode a 'TL.Text' value in Base64url without padding. Note that for Base64url,
-- padding is optional. If you call this function, you will simply be encoding
-- as Base64url and stripping padding chars from the output.
--
-- See: <https://tools.ietf.org/html/rfc4648#section-3.2 RFC-4648 section 3.2>
--
-- === __Examples__:
--
-- >>> encodeBase64Unpadded "<<?>>"
-- "PDw_Pj4"
--
encodeBase64Unpadded :: TL.Text -> Base64 'UrlUnpadded TL.Text
encodeBase64Unpadded = BL64U.encodeBase64Unpadded . TL.encodeUtf8
{-# INLINE encodeBase64Unpadded #-}

-- | Decode an unpadded Base64url encoded 'TL.Text' value.
--
-- /Note:/ This function makes sure that decoding is total by deferring to
-- 'T.decodeLatin1'. This will always round trip for any valid Base64-encoded
-- text value, but it may not round trip for bad inputs. The onus is on the
-- caller to make sure inputs are valid. If unsure, defer to `decodeBase64WUnpaddedWith`
-- and pass in a custom decode function.
--
-- See: <https://tools.ietf.org/html/rfc4648#section-4 RFC-4648 section 4>
--
-- === __Examples__:
--
-- >>> decodeBase64Unpadded "PDw_Pj4"
-- Right "<<?>>"
--
-- >>> decodeBase64Unpadded "PDw_Pj4="
-- Left "Base64-encoded bytestring has invalid padding"
--
decodeBase64Unpadded :: Base64 'UrlUnpadded TL.Text -> Either T.Text TL.Text
decodeBase64Unpadded = fmap TL.decodeLatin1
    . BL64U.decodeBase64Unpadded
    . fmap TL.encodeUtf8
{-# INLINE decodeBase64Unpadded #-}

-- | Attempt to decode an unpadded lazy 'ByteString' value as Base64url, converting from
-- 'ByteString' to 'TL.Text' according to some encoding function. In practice,
-- This is something like 'decodeUtf8'', which may produce an error.
--
-- See: <https://tools.ietf.org/html/rfc4648#section-4 RFC-4648 section 4>
--
-- === __Examples__:
--
-- @
-- 'decodeBase64UnpaddedWith' 'TL.decodeUtf8''
--   :: 'ByteString' -> 'Either' ('Base64Error' 'UnicodeException') 'TL.Text'
-- @
--
decodeBase64UnpaddedWith
    :: (ByteString -> Either err TL.Text)
      -- ^ convert a bytestring to text (e.g. 'TL.decodeUtf8'')
    -> Base64 'UrlUnpadded ByteString
      -- ^ Input text to decode
    -> Either (Base64Error err) TL.Text
decodeBase64UnpaddedWith f t = case BL64U.decodeBase64Unpadded t of
  Left de -> Left $ DecodeError de
  Right a -> first ConversionError (f a)
{-# INLINE decodeBase64UnpaddedWith #-}

-- | Decode an padded Base64url encoded 'TL.Text' value
--
-- /Note:/ This function makes sure that decoding is total by deferring to
-- 'T.decodeLatin1'. This will always round trip for any valid Base64-encoded
-- text value, but it may not round trip for bad inputs. The onus is on the
-- caller to make sure inputs are valid. If unsure, defer to `decodeBase64PaddedWith`
-- and pass in a custom decode function.
--
-- See: <https://tools.ietf.org/html/rfc4648#section-4 RFC-4648 section 4>
--
-- === __Examples__:
--
-- >>> decodeBase64Padded "PDw_Pj4="
-- Right "<<?>>"
--
-- >>> decodeBase64Padded "PDw_Pj4"
-- Left "Base64-encoded bytestring requires padding"
--
decodeBase64Padded :: Base64 'UrlPadded TL.Text -> Either T.Text TL.Text
decodeBase64Padded = fmap TL.decodeLatin1
    . BL64U.decodeBase64Padded
    . fmap TL.encodeUtf8
{-# INLINE decodeBase64Padded #-}

-- | Attempt to decode a padded lazy 'ByteString' value as Base64url, converting from
-- 'ByteString' to 'TL.Text' according to some encoding function. In practice,
-- This is something like 'decodeUtf8'', which may produce an error.
--
-- See: <https://tools.ietf.org/html/rfc4648#section-4 RFC-4648 section 4>
--
-- === __Example__:
--
-- @
-- 'decodeBase64PaddedWith' 'T.decodeUtf8''
--   :: 'ByteString' -> 'Either' ('Base64Error' 'UnicodeException') 'Text'
-- @
--
decodeBase64PaddedWith
    :: (ByteString -> Either err TL.Text)
      -- ^ convert a bytestring to text (e.g. 'TL.decodeUtf8'')
    -> Base64 'UrlPadded ByteString
      -- ^ Input text to decode
    -> Either (Base64Error err) TL.Text
decodeBase64PaddedWith f t = case BL64U.decodeBase64Padded t of
  Left de -> Left $ DecodeError de
  Right a -> first ConversionError (f a)
{-# INLINE decodeBase64PaddedWith #-}

-- | Leniently decode an unpadded Base64url-encoded 'TL.Text'. This function
-- will not generate parse errors. If input data contains padding chars,
-- then the input will be parsed up until the first pad character.
--
-- __Note:__ This is not RFC 4648-compliant.
--
-- === __Examples__:
--
-- >>> decodeBase64Lenient "PDw_Pj4="
-- "<<?>>"
--
-- >>> decodeBase64Lenient "PDw_%%%$}Pj4"
-- "<<?>>"
--
decodeBase64Lenient :: Base64 k TL.Text -> TL.Text
decodeBase64Lenient = TL.decodeLatin1
    . BL64U.decodeBase64Lenient
    . fmap TL.encodeUtf8
{-# INLINE decodeBase64Lenient #-}

-- | Tell whether a 'TL.Text' value is Base64url-encoded
--
-- === __Examples__:
--
-- >>> isBase64Url "PDw_Pj4="
-- True
--
-- >>> isBase64Url "PDw_Pj4"
-- True
--
-- >>> isBase64Url "PDw_Pj"
-- False
--
isBase64Url :: TL.Text -> Bool
isBase64Url = BL64U.isBase64Url . TL.encodeUtf8
{-# INLINE isBase64Url #-}

-- | Tell whether a 'TL.Text' value is a valid Base64url format.
--
-- This will not tell you whether or not this is a correct Base64url representation,
-- only that it conforms to the correct shape. To check whether it is a true
-- Base64 encoded 'TL.Text' value, use 'isBase64Url'.
--
-- === __Examples__:
--
-- >>> isValidBase64Url "PDw_Pj4="
-- True
--
-- >>> isValidBase64Url "PDw_Pj"
-- True
--
-- >>> isValidBase64Url "%"
-- False
--
isValidBase64Url :: TL.Text -> Bool
isValidBase64Url = BL64U.isValidBase64Url . TL.encodeUtf8
{-# INLINE isValidBase64Url #-}
