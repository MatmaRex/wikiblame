# coding: utf-8
require 'inline'

class PatchRecorder < Array
	inline :C do |builder|
		builder.add_compile_flags '-x c++', '-lstdc++'

		builder.c %[
			void nudge_marks(VALUE length_, VALUE index_, VALUE type) {
				VALUE marks = rb_iv_get(self, "@marks");
			
				int index = NUM2INT(index_);
				int length = NUM2INT(length_);
				
				if(type == ID2SYM(rb_intern("-"))) {
					for(int i=0; i<RARRAY_LEN(marks); i++) {
						VALUE m = *( RARRAY_PTR(marks) + i );
						int m_index = NUM2INT( RSTRUCT_PTR(m)[0] ); // index => 0th position in the Struct
						int m_length = NUM2INT( RSTRUCT_PTR(m)[2] ); // length => 2nd position in the Struct
						
						if(m_index>=index) {
							if(m_index>index+length) {
								m_index-=length;
							} else {
								m_length-=index+length-m_index;
								m_index=index;
							}
						} else {
							if(m_index+m_length<=index) {
								// do nothing
							} else {
								m_length-=length;
							}
						}
						
						if(m_length<1 || m_index<0) {
							// this mark has essentially disappeared
							// replace with a nil to remove later with a #compact! call
							*( RARRAY_PTR(marks) + i ) = Qnil;
						} else {
							RSTRUCT_PTR(m)[0] = INT2NUM(m_index); // index => 0th position in the Struct
							RSTRUCT_PTR(m)[2] = INT2NUM(m_length); // length => 2nd position in the Struct
						}
					}
				} else {
					for(int i=0; i<RARRAY_LEN(marks); i++) {
						VALUE m = *( RARRAY_PTR(marks) + i );
						int m_index = NUM2INT( RSTRUCT_PTR(m)[0] ); // index => 0th position in the Struct
						int m_length = NUM2INT( RSTRUCT_PTR(m)[2] ); // length => 2nd position in the Struct
						
						if(m_index>=index) {
							if(m_index>index+length) {
								m_index+=length;
							} else {
								m_index+=length;
							}
						} else {
							if(m_index+m_length<=index) {
								// do nothing
							} else {
								m_length+=length;
							}
						}
						
						if(m_length<1 || m_index<0) {
							// this mark has essentially disappeared
							// replace with a nil to remove later with a #compact! call
							*( RARRAY_PTR(marks) + i ) = Qnil;
						} else {
							RSTRUCT_PTR(m)[0] = INT2NUM(m_index); // index => 0th position in the Struct
							RSTRUCT_PTR(m)[2] = INT2NUM(m_length); // length => 2nd position in the Struct
						}
					}
				}
				
				rb_funcall(marks, rb_intern("compact!"), 0);
			}
		]
	end
end



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
