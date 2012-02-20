require 'unicode'
# A Slug is a unique, human-friendly identifier for an ActiveRecord.
class Slug < ActiveRecord::Base

  belongs_to :sluggable, :polymorphic => true
  before_save :check_for_blank_name, :set_sequence

  class << self

    # Sanitizes and dasherizes string to make it safe for URL's.
    #
    # Example:
    #
    #   slug.normalize('This... is an example!') # => "this-is-an-example"
    #
    # Note that Rails 2.2.x offers a parameterize method for this. It's not
    # used here because it assumes you want to strip away accented characters,
    # and this may not always be your desire.
    #
    # At the time of writing, it also handles several characters incorrectly,
    # for instance replacing Icelandic's "thorn" character with "y" rather
    # than "d." This might be pedantic, but I don't want to piss off the
    # Vikings. The last time anyone pissed them off, they uleashed a wave of
    # terror in Europe unlike anything ever seen before or after. I'm not
    # taking any chances.
    def normalize(slug_text)
      return "" if slug_text.nil? || slug_text == ""
      Unicode::normalize_KC(slug_text).
        send(chars_func).
        # For some reason Spanish ¡ and ¿ are not detected as non-word
        # characters. Bug in Ruby?
        gsub(/[\W|¡|¿]/u, ' ').
        strip.
        gsub(/\s+/u, '-').
        gsub(/-\z/u, '').
        downcase.
        to_s
    end

    def parse(friendly_id)
      name, sequence = friendly_id.split('--')
      sequence ||= "1"
      return name, sequence
    end

    # Remove diacritics (accents, umlauts, etc.) from the string. Borrowed
    # from "The Ruby Way."
    def strip_diacritics(string)
      Unicode::normalize_KD(string).unpack('U*').select { |u| u < 0x300 || u > 0x036F }.pack('U*')
    end
    
    # Remove non-ascii characters from the string.
    def strip_non_ascii(string)
      strip_diacritics(string).gsub(/[^a-z0-9]+/i, ' ')
    end

    private

    def chars_func
      "".respond_to?(:mb_chars) ? :mb_chars : :chars
    end

  end

  # Whether or not this slug is the most recent of its owner's slugs.
  def is_most_recent?
    sluggable.slug == self
  end

  def to_friendly_id
    sequence > 1 ? "#{name}--#{sequence}" : name
  end

  protected

  # Raise a FriendlyId::SlugGenerationError if the slug name is blank.
  def check_for_blank_name #:nodoc:#
    if name == "" || name.nil?
      raise FriendlyId::SlugGenerationError.new("The slug text is blank.")
    end
  end

  def set_sequence
    return unless new_record?
    last = Slug.find(:first, :conditions => { :name => name, :scope => scope,
      :sluggable_type => sluggable_type}, :order => "sequence DESC",
      :select => 'sequence')
    self.sequence = last.sequence + 1 if last
  end

end