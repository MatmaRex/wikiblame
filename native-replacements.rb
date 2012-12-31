# coding: utf-8
require 'diff-lcs'

# Monkey-patch Diff::LCS to use native C++ binary search instead of homemade Ruby solution.

class << Diff::LCS
	def __replace_next_larger(enum, value, last_index = nil)
		# Off the end?
		if enum.empty? or (value > enum[-1])
			enum << value
			return enum.size - 1
		end

		# Binary search for the insertion point
		first_index = CppAlgorithm.lower_bound(enum, value)
		return nil if enum[first_index] == value

		# The insertion point is in first_index; overwrite the next larger
		# value.
		enum[first_index] = value
		return first_index
	end
end
