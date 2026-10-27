module Media
  # Reads an MP4's duration from its movie header (moov/mvhd) with a few small ranged reads, so a
  # video in object storage is never downloaded whole just to be checked.
  class Mp4Probe
    MAX_TOP_LEVEL_BOXES = 32
    MVHD_WINDOW = 256 # mvhd is the first child of moov and far smaller than this

    def self.duration(blob) = new(blob).duration

    def initialize(blob)
      @blob = blob
    end

    # Seconds as a Float, or nil when the file has no readable movie header.
    def duration
      offset = 0
      MAX_TOP_LEVEL_BOXES.times do
        break if offset + 8 > @blob.byte_size

        size, type = read(offset, 8).unpack("Na4")
        header = 8
        if size == 1 # 64-bit box size follows the type
          size = read(offset + 8, 8).unpack1("Q>")
          header = 16
        elsif size.zero? # box runs to the end of the file
          size = @blob.byte_size - offset
        end
        return nil if size < header

        return mvhd_duration(read(offset + header, [ size - header, MVHD_WINDOW ].min)) if type == "moov"

        offset += size
      end
      nil
    end

    private

    def read(offset, length)
      @blob.download_chunk(offset...(offset + length)).b
    end

    # mvhd: version(1) flags(3), then v0: ctime(4) mtime(4) timescale(4) duration(4)
    #                                 v1: ctime(8) mtime(8) timescale(4) duration(8)
    def mvhd_duration(moov)
      index = moov.index("mvhd")
      return nil unless index

      body = moov.byteslice(index + 4..)
      timescale, duration =
        if body.getbyte(0) == 1
          body.byteslice(20, 12)&.unpack("NQ>")
        else
          body.byteslice(12, 8)&.unpack("NN")
        end
      timescale.to_i.positive? ? duration.to_f / timescale : nil
    end
  end
end
