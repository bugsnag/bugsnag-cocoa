find Source -iname *.h -o -iname *.c -iname *.m -iname *.mm | xargs clang-format -i;
find Tests -iname *.m | xargs clang-format -i;

