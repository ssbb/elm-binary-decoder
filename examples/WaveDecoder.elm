module WaveDecoder exposing (..)


import BinaryDecoder exposing (..)
import BinaryDecoder.Byte exposing (..)


type alias Wave =
  { size : Int
  , format : Format
  , data : Data
  }


type alias Format =
  { size : Int
  , format : Int
  , channels : Int
  , sampleRate : Int
  , bytePerSec : Int
  , blockAlign : Int
  , bitsWidth : Int
  , extendedSize : Int
  }


type alias Data =
  { dataSize : Int
  }


wave : Decoder Wave
wave =
  succeed Wave
    |. symbol "RIFF"
    |= uint32BE
    |. symbol "WAVE"
    |= formatChunk
    |= dataChunk


formatChunk : Decoder Format
formatChunk =
  succeed identity
    |. symbol "fmt "
    |= (uint32BE |> andThen (\size ->
        succeed (Format size)
          |= uint16BE
          |= uint16BE
          |= uint32BE
          |= uint32BE
          |= uint16BE
          |= uint16BE
          |= if size > 16 then uint16BE else succeed 0
      ))


dataChunk : Decoder Data
dataChunk =
  succeed Data
    |. symbol "data"
    |= uint32BE
