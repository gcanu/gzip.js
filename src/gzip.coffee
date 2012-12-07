#
# GZIP Decompression
#
# Copyright (c) Guillaume Canu (https://github.com/gcanu/gzip.js)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# Version : 0.1a
# Documentation : RFC 1951 (http://tools.ietf.org/html/rfc1951)
#                 RFC 1952 (http://tools.ietf.org/html/rfc1952)
#

(() ->

  decompress = (cText) ->
    
    ##
    ## VARIABLES INITIALIZATION
    ##
    
    # global vars
    id1 = id2 = cm = flg = mtime = xfl = os = filename = null
    
    # uncompressed text
    text = ""  
    
    # bit pointer
    b = 0      


  
    ##
    ## INTERNAL FUNCTIONS
    ##
    
    #
    # Read file header
    #
    getFileHeader = ->
      id1   = getBitsSequence 8,  true
      id2   = getBitsSequence 8,  true
      cm    = getBitsSequence 8,  true
      flg   = getBitsSequence 8,  true
      mtime = getBitsSequence 32, true
      xfl   = getBitsSequence 8,  true
      os    = getBitsSequence 8,  true
      
      filename = readFileName()
      
     
     
    #
    # Read the 3-bits header from block
    #
    getHeader = ->
      bfinal = getBitsSequence 1
      # we must invert the btype bits sequence
      btype = (getBitsSequence 1) | ((getBitsSequence 1) << 1)
      { bfinal: bfinal, btype: btype }
      
      
    
    #
    # Read file name
    #
    readFileName = ->
      str = ""
      car = 1
      while car != 0
        car = getBitsSequence 8, true
        str += String.fromCharCode car
      str
    
    
    
    #
    # the following method give the huffman codes for fixed huffman compression method
    #
    
    getHuffmanCodes = (cl) ->
      return null if cl is null or cl is undefined
      
      # variables initialization
      minCodeLength = 7777
      maxCodeLength = 0
      
      # etape 0
      a = []
      for el, i in cl
        a[i] = el if el > 0

      # etape 1
      bl_count = []
      for el in a
        bl_count[el] = 0 if bl_count[el] is undefined
        bl_count[el]++
        # not useful for the present algorithm but important for the program
        minCodeLength = el if el < minCodeLength
        maxCodeLength = el if el > maxCodeLength

      # etape 2
      code = 0
      next_code = []
      for bits in [1..bl_count.length-1]
        value = bl_count[bits-1]
        value = 0 if value is undefined
        code = (code + value) << 1
        next_code[bits] = code

      # etape 3
      hcodes = {}
      for el, i in a
        if el isnt undefined
          len = el;
          if len != 0
            hcodes[len] = [] if hcodes[len] is undefined
            hcodes[len][i] = next_code[len]
            next_code[len]++
            
      # adding info on code lengths
      hcodes["minCodeLength"] = minCodeLength
      hcodes["maxCodeLength"] = maxCodeLength
          
      hcodes
      
      
      
    #
    # get a sequence of bits
    #
    
    getBitsSequence = (l, r) ->
      return 0 if l == 0
      return null if l > 32
      
      r = false if r is undefined
      
      getMask = (pos) ->
        return Math.pow 2,pos if 0 <= pos < 8
        0
      
      for i in [0..l-1]
        o = cText.charCodeAt Math.floor b/8
        bit = ( o & getMask(b%8) ) >> (b%8)
        
        if r is false
          seq = (seq<<1) | bit
        else
          seq |= bit<<i
        b++
        
      seq



    #
    # get the next huffman code
    #
    
    getNextCode = (codes) ->
      l = codes.minCodeLength
      while l <= codes.maxCodeLength
        if codes[l] isnt null && codes[l] isnt undefined
          code = codes[l].indexOf getBitsSequence l
          if code != -1 then return code else b -= l++
        else
          l++
      null
     
     
    #
    # read a special code
    #
    getNextDynamicCode = ->
      codeLengths = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]
      
      hlit  = getBitsSequence(5, true) + 257
      hdist = getBitsSequence(5, true) + 1
      hclen = getBitsSequence(4, true) + 4
      
      
      # construct the lengths list
      hclens = []
      for i in [0..codeLengths.length-1]
        if i < hclen
          hclens[codeLengths[i]] = getBitsSequence 3, true
        else
          hclens[codeLengths[i]] = 0
        
        
      # get the huffman codes for code length alphabet
      codes = getHuffmanCodes hclens
      
      # set the repeat function
      repeat = (code, times) ->
        tab = []
        tab.push code for i in [0..times-1]
        tab

      # read the literal/length alphabet
      alphabets = []
      while alphabets.length < hlit+hdist
        code = getNextCode codes
        
        return null if code is null
        
        if code < 16
          alphabets.push code
        else if code == 16
          alphabets = alphabets.concat repeat prevcode, getBitsSequence(2, true)+3
        else if code == 17
          alphabets = alphabets.concat repeat 0, getBitsSequence(3, true)+3
        else if code == 18
          alphabets = alphabets.concat repeat 0, getBitsSequence(7, true)+11
        
        prevcode = code
        
      # alphabet slicing
      hlitalph = alphabets.slice 0, hlit
      hdistalph = alphabets.slice -hdist
      
      # reconstitution of literal alphabet
      litalph = getHuffmanCodes hlitalph
      
      # reconstitution of distance alphabet
      distalph = getHuffmanCodes hdistalph
      
      # read the following bits with the literal alphabet      
      code = 0
      car = ""
      subtext = ""
      while code != 256
        code = getNextCode litalph
        
        return null if code is null          
          
        if 0 < code < 255
            text += String.fromCharCode code
        else if code > 256
          block = readCompressedBlock code, distalph
          return null if block is null
          
          if block.dist >= block.len
            text += text.substr text.length-block.dist, block.len
          
          # in some case the length code is bigger than the dist code, so we 
          # must to repeat the last pattern defined by dist and length until 
          # reach the desired length
          else
            stext = ""
            for i in [0..block.len-1]
              stext += text.substr text.length-block.dist+i%block.dist, 1
            text += stext
      
      true
      
      
    
    #
    # read a special code
    #
    readCompressedBlock = (cb, distalph) ->
      return null if 285 < cb < 257
      
      # default set dist
      distalph = distalph || null
      
      # return the minimum length for a code n
      getEBLen = (n) ->
        if n > 264
          return Math.ceil((n-264)/4)
        else
          return 0
        
      getEBDist = (n) ->
        if n > 3
          return Math.ceil((n-3)/2)
        else
          return 0
        
      getMinLen = (n) ->
        return null if n > 284 
        if n <= 264
          return 3+(n-257)
        else
          return getMinLen(n-1)+(Math.pow(2, getEBLen n-1))
      
      getMinDistance = (n) ->
        return null if 29 < n < 0
        if n <= 3
          return n+1
        else
          return getMinDistance(n-1)+(Math.pow(2, getEBDist n-1))
      
      # get the len
      if cb == 285
        len = 258
      else
        len = getMinLen(cb)+(getBitsSequence(getEBLen(cb), true))
        
      # get the distance
      if distalph is null
        distCode = getBitsSequence 5
      else
        distCode = getNextCode distalph
        return null if distCode is null
      
      dist = getMinDistance(distCode)+(getBitsSequence(getEBDist(distCode), true))
      
      # return result
      { len: len, dist: dist}
    
    
    
    ##
    ## METHOD EXECUTION
    ##
    
    getFileHeader()
    
    blockHeader = getHeader()
    endofblock = false
    
    if blockHeader.btype == 1
    
      # prepare default code length
      defCodeLengths = []
      defCodeLengths.push 8 for i in [0..143]
      defCodeLengths.push 9 for i in [144..255]
      defCodeLengths.push 7 for i in [256..279]
      defCodeLengths.push 8 for i in [280..287]
      
      # fixed Huffman codes
      codes = getHuffmanCodes defCodeLengths
      
      while endofblock is false
        code = getNextCode codes
        
        return null if distCode is null
          
        if code < 256
          text += String.fromCharCode code
        else if code == 256
          endofblock = true
        else
          block = readCompressedBlock code
          return null if block is null
            
          text += text.substr text.length-block.dist, block.len
    
    else if blockHeader.btype == 2
        code = getNextDynamicCode()
        if code is null then return null

    # return decompressed text      
    text
    
)()