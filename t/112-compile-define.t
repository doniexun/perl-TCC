#!perl
# A test to check that the compiler works and can invoke code.

use 5.006;
use strict;
use warnings;
use Test::More tests => 14;

use inc::Capture;

############## compile and run a simple printout function

my $results = Capture::it(<<'TEST_CODE');
use TCC;

# Build the context with some simple code:
my $context= TCC->new;
$context->code('Body') = q{
	void print_hello() {
		printf("Hello from TCC\n");
	}
};
$context->compile;
print "OK: compiled\n";

# Call the compiled function:
$context->call_void_function('print_hello');

print "Done\n";
TEST_CODE

############## simple code compilation: 4
isnt($results, undef, 'Got sensible results')
	or diag($results);
like($results, qr/OK: compiled/, "Compiles without trouble");
like($results, qr/Hello from TCC/, "Calls and executes a function");
like($results, qr/Done/, "Continues after the function call");

############## exercise the #define behavior within TCC: 1

$results = Capture::it(<<'TEST_CODE');
use TCC;
my $context = TCC->new;
$context->code('Body') = q{
	#define PRINT(arg) printf(arg)
	void print_hello() {
		PRINT("Hello from TCC\n");
	}
};
$context->compile;
$context->call_void_function('print_hello');
TEST_CODE

like($results, qr/Hello from TCC/, 'Simple in-code #define');

############## exercise the Perl-side define function: 1

$results = Capture::it(<<'TEST_CODE');
use TCC;
my $context = TCC->new;
$context->define('PRINT(arg)' => 'printf(arg)');
$context->code('Body') = q{
	void print_hello() {
		PRINT("Hello from TCC\n");
	}
};
$context->compile;
$context->call_void_function('print_hello');
TEST_CODE

like($results, qr/Hello from TCC/, 'Perl in-code #define');

############## variadic macros in TCC: 3

$results = Capture::it(<<'TEST_CODE');
use TCC;
my $context = TCC->new;
my %variadic = qw(
	...			__VA_ARGS__
	args...		args
	arg,...		arg,__VA_ARGS__
);
my $i = 0;
while (my ($input, $output) = each %variadic) {
	$context->code('Body') .= qq{
		#define PRINT$i($input) printf($output)
		void print$i() {
			PRINT$i("input %s\n", "$input");
		}
	};
	$i++;
}
$context->compile;
$i = 0;
for (keys %variadic) {
	$context->call_void_function("print$i");
	$i++;
}
TEST_CODE

like($results, qr/input .../, 'Variadic macro #define func(...) in TCC');
like($results, qr/input args.../, 'Variadic macro #define func(args...) in TCC');
like($results, qr/input arg,.../, 'Variadic macro #define func(arg,...) in TCC');

############## variadic macros from Perl: 3

$results = Capture::it(<<'TEST_CODE');
use TCC;
my $context = TCC->new;
my %variadic = qw(
	...			__VA_ARGS__
	args...		args
	arg,...		arg,__VA_ARGS__
);
my $i = 0;
while (my ($input, $output) = each %variadic) {
	$context->code('Body') .= qq{
		void print$i() {
			PRINT$i("input %s\n", "$input");
		}
	};
	$context->define("PRINT$i($input)" => "printf($output)");
	$i++;
}
$context->compile;
$i = 0;
for (keys %variadic) {
	$context->call_void_function("print$i");
	$i++;
}
TEST_CODE

like($results, qr/input .../, 'Variadic macro #define func(...) from Perl');
like($results, qr/input args.../, 'Variadic macro #define func(args...) from Perl');
like($results, qr/input arg,.../, 'Variadic macro #define func(arg,...) from Perl');

############## token pasting in TCC and from Perl: 2
# Tests an example in the docs, under the define method. Update the note in
# this docs if this is removed or moved to a different file.

$results = Capture::it(<<'TEST_CODE');
use TCC;
my $context = TCC->new;

# Define it Perl-side:
$context->define('DEBUG_PRINT_INT1(val)'
     , 'printf("For " #val ", got %d\n", val)');

$context->code('Body') .= q{
	/* Define it TCC-side */
	#define DEBUG_PRINT_INT2(val) printf("For " #val ", got %d\n", val)
	
	void test() {
		int a = 1;
		int b = 2;
		DEBUG_PRINT_INT1(a);
		DEBUG_PRINT_INT2(b);
	}
};
$context->compile;
$context->call_void_function("test");
TEST_CODE

like($results, qr/For a, got 1/, 'Perl-side token pasting macros');
like($results, qr/For b, got 2/, 'TCC-side token pasting macros');
