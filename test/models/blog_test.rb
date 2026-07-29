require "stringio"
require "test_helper"

class BlogTest < ActiveSupport::TestCase
  test "a thumbnail can be attached" do
    blog = blogs(:one)

    blog.thumbnail.attach(
      io: StringIO.new("test thumbnail"),
      filename: "thumbnail.txt",
      content_type: "text/plain"
    )

    assert blog.thumbnail.attached?
    assert_equal "thumbnail.txt", blog.thumbnail.filename.to_s
  ensure
    blog.thumbnail.purge if blog&.thumbnail&.attached?
  end
end
