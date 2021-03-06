module Mp3Decoder exposing (..)


import Bitwise
import Char
import BinaryDecoder exposing (..)
import BinaryDecoder.Byte exposing (..)
import BinaryDecoder.Bit as Bit exposing (..)


type alias Mp3 =
  { tagId3v2 : TagId3v2
  }


type alias TagId3v2 =
  { header : TagId3v2Header
  , expansion : Maybe ExpansionHeader
  , frames : List TagId3v2Frame
  }


type alias ExpansionHeader =
  {}


type alias TagId3v2Header =
  { majorVersion : Int
  , minorVersion : Int
  , flags : TagId3v2HeaderFlags
  , size : Int
  }


type alias TagId3v2HeaderFlags =
  { sync : Bool
  , expansion : Bool
  , experimental : Bool
  , footer : Bool
  }


type alias TagId3v2Footer =
  {}



type alias FrameHeader =
  { version : Version
  , layer : Layer
  , protection : Bool
  , bitRate : Int
  , sampleRate : Int
  , padding : Bool
  , extension : Bool
  , channelMode : ChannelMode
  , copyright : Bool
  , original : Bool
  , emphasis : String
  }


type Version
  = MPEGv25
  | MPEGv2
  | MPEGv1


type Layer
  = Layer3
  | Layer2
  | Layer1


type ChannelMode
  = JointStereo Int
  | Stereo
  | DualChannel
  | SingleChannel


mp3 : Decoder Mp3
mp3 =
  succeed Mp3
    |= tagId3v2


tagId3v2 : Decoder TagId3v2
tagId3v2 =
  tagId3v2Header
    |> andThen (\header ->
      succeed (TagId3v2 header)
        |= ( if header.flags.expansion then
               expansionHeader |> map Just
             else
               succeed Nothing )
        |= many tagId3v2Frame
        |. skip ( if header.flags.footer then 10 else 0 )
    )


tagId3v2Header : Decoder TagId3v2Header
tagId3v2Header =
  succeed TagId3v2Header
    |. symbol "ID3"
    |= uint8
    |= uint8
    |= ( bits 1 <|
          succeed TagId3v2HeaderFlags
            |= Bit.bool
            |= Bit.bool
            |= Bit.bool
            |= Bit.bool
        )
    |= syncSafeInt


expansionHeader : Decoder ExpansionHeader
expansionHeader =
  uint32BE
    |> andThen (\size ->
      succeed ExpansionHeader
        |. skip size
    )


type alias TagId3v2Frame =
  { header : TagId3v2FrameHeader
  , body : TagId3v2FrameBody
  }


type alias TagId3v2FrameHeader =
  { id : String -- UFID, TIT2, TPE1, TRCK, MCDI,...
  , size : Int
  , flags : TagId3v2FrameHeaderFlags -- from 2.3
  }


type alias TagId3v2FrameHeaderFlags =
  { a1 : Bool
  , a2 : Bool
  , a3 : Bool
  , a4 : Bool
  , a5 : Bool
  , a6 : Bool
  , a7 : Bool
  , a8 : Bool
  }


type alias TagId3v2FrameBody =
  {}



tagId3v2Frame : Decoder TagId3v2Frame
tagId3v2Frame =
  tagId3v2FrameHeader
    |> andThen (\header ->
      succeed (TagId3v2Frame header)
        |. skip header.size
        |= succeed TagId3v2FrameBody
    )


tagId3v2FrameHeader : Decoder TagId3v2FrameHeader
tagId3v2FrameHeader =
  succeed TagId3v2FrameHeader
    |= tagId3v2FrameHeaderId
    |= uint32BE
    |= tagId3v2FrameHeaderFlags -- from v2.3


tagId3v2FrameHeaderId : Decoder String
tagId3v2FrameHeaderId =
  uint8
    |> andThen (\i ->
        if 48 <= i && i <= 57 || 65 <= i && i <= 90 then
          succeed (Char.fromCode i)
        else
          fail "invalid id"
      )
    |> repeat 4
    |> map String.fromList


tagId3v2FrameHeaderFlags : Decoder TagId3v2FrameHeaderFlags
tagId3v2FrameHeaderFlags =
  bits 2 <|
    succeed TagId3v2FrameHeaderFlags
      |. goTo 1
      |= Bit.bool
      |= Bit.bool
      |= Bit.bool
      |. goTo 9
      |= Bit.bool
      |. goTo 12
      |= Bit.bool
      |= Bit.bool
      |= Bit.bool
      |= Bit.bool


frameHeader : Decoder FrameHeader
frameHeader =
  bits 4 <|
    succeed FrameHeader
      |. ones 11
      |= Bit.choose 2 [ (0, MPEGv25), (2, MPEGv2), (3, MPEGv1) ]
      |= Bit.choose 2 [ (1, Layer3), (2, Layer2), (3, Layer1) ]
      |= Bit.bool
      |= int 4
      |= int 2
      |= Bit.bool
      |= Bit.bool
      |= channelMode
      |= Bit.bool
      |= Bit.bool
      |= Bit.choose 2 [ (1, "50/15"), (2, ""), (3, "CCIT J.17") ]


channelMode : BitDecoder ChannelMode
channelMode =
  int 2
    |> andThen (\i ->
      if i == 1 then
        succeed JointStereo
          |= int 2
      else
        succeed (
          if i == 0 then
            Stereo
          else if i == 2 then
            DualChannel
          else
            SingleChannel
        )
          |. zeros 2
    )


syncSafeInt : Decoder Int
syncSafeInt =
  succeed (\a b c d -> a + b + c + d)
    |= map (Bitwise.and 255 >> Bitwise.shiftLeftBy 21) uint8
    |= map (Bitwise.and 255 >> Bitwise.shiftLeftBy 14) uint8
    |= map (Bitwise.and 255 >> Bitwise.shiftLeftBy 7) uint8
    |= map (Bitwise.and 255) uint8
