for ext in h m c cpp mm; do 
    find . -type f -name *.$ext | xargs clang-format -i;
done
