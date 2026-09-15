
## 3. not-match

can we

```scheme
(
 (region_start)
 .
  [
    (_)+ @fold_content
    (#not-match? @fold_content "^region_end$")
  ] @fold
 .
 (region_end)
)
```


## 4. any-not-eq?
