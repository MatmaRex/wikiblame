# coding: utf-8
require 'inline'

module CppAlgorithm
	inline :C do |builder|
		builder.include '<algorithm>'
		builder.add_compile_flags '-x c++', '-lstdc++', '-std=c++0x'

		builder.c '
		VALUE lower_bound(VALUE r_array, VALUE value) {
			VALUE* array = RARRAY_PTR(r_array);
			int len = RARRAY_LEN(r_array);
			
			VALUE* found;
			
			if(rb_block_given_p()) {
				auto proc = rb_block_proc();
				found = std::lower_bound(
					array, array+len, value,
					[proc](VALUE a, VALUE b) -> int { return NUM2INT( rb_funcall(proc, rb_intern("call"), 2, a, b) ) < 0; }
				);
			} else {
				found = std::lower_bound(
					array, array+len, value,
					[](VALUE a, VALUE b) -> int { return NUM2INT( rb_funcall(a, rb_intern("<=>"), 1, b) ) < 0; }
				);
			}
			
			return INT2NUM(found-array);
		}'

		builder.c '
		VALUE upper_bound(VALUE r_array, VALUE value) {
			VALUE* array = RARRAY_PTR(r_array);
			int len = RARRAY_LEN(r_array);
			
			VALUE* found;
			
			if(rb_block_given_p()) {
				auto proc = rb_block_proc();
				found = std::upper_bound(
					array, array+len, value,
					[proc](VALUE a, VALUE b) -> int { return NUM2INT( rb_funcall(proc, rb_intern("call"), 2, a, b) ) < 0; }
				);
			} else {
				found = std::upper_bound(
					array, array+len, value,
					[](VALUE a, VALUE b) -> int { return NUM2INT( rb_funcall(a, rb_intern("<=>"), 1, b) ) < 0; }
				);
			}
			
			return INT2NUM(found-array);
		}'

		builder.c '
		VALUE binary_search(VALUE r_array, VALUE value) {
			VALUE* array = RARRAY_PTR(r_array);
			int len = RARRAY_LEN(r_array);
			
			int found;
			
			if(rb_block_given_p()) {
				auto proc = rb_block_proc();
				found = std::binary_search(
					array, array+len, value,
					[proc](VALUE a, VALUE b) -> int { return NUM2INT( rb_funcall(proc, rb_intern("call"), 2, a, b) ) < 0; }
				);
			} else {
				found = std::binary_search(
					array, array+len, value,
					[](VALUE a, VALUE b) -> int { return NUM2INT( rb_funcall(a, rb_intern("<=>"), 1, b) ) < 0; }
				);
			}
			
			return found ? Qtrue : Qfalse;
		}'
	end
	
	# make the methods available as CppAlgorithm.x
	class << CppAlgorithm
		include CppAlgorithm
	end
end

if __FILE__ == $0
	array = (1..10).to_a - [5]
	p array

	args = [4, 5, 6, 15, -1]
	args.each do |n|
		puts "#{n}:"
		puts "  ary.index       = #{(array.index n).inspect}"
		puts "  lower_bound     = #{(CppAlgorithm.lower_bound array, n).inspect}"
		puts "  upper_bound     = #{(CppAlgorithm.upper_bound array, n).inspect}"
		puts "  ary.include?    = #{(array.include? n).inspect}"
		puts "  binary_search   = #{(CppAlgorithm.binary_search array, n).inspect}"
	end
	
	puts ''
	
	array = ((1..10).to_a - [5]).reverse
	p array

	args = [4, 5, 6, 15, -1]
	args.each do |n|
		puts "#{n}:"
		puts "  ary.index       = #{(array.index n).inspect}"
		puts "  lower_bound{}   = #{(CppAlgorithm.lower_bound(array, n){|a,b| b<=>a }).inspect}"
		puts "  upper_bound{}   = #{(CppAlgorithm.upper_bound(array, n){|a,b| b<=>a }).inspect}"
		puts "  ary.include?    = #{(array.include? n).inspect}"
		puts "  binary_search{} = #{(CppAlgorithm.binary_search(array, n){|a,b| b<=>a }).inspect}"
	end
end
