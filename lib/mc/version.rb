module MC
  # have to check const defined for 1.8.7 to avoid warnings
  VERSION = '0.0.6' unless const_defined?(:VERSION)
end
