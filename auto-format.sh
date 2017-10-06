find Source -iname *.h | xargs clang-format -i;
find Source -iname *.m | xargs clang-format -i;
find Source -iname *.c | xargs clang-format -i;
find Source -iname *.mm | xargs clang-format -i;
find Tests -iname *.m | xargs clang-format -i;

