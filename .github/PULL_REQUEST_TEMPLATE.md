## Goal

<!-- What is the intent of this change? -->

<!--
Fixes #
Related to #
-->

## Design

<!-- How does this change work? Why was this approach to the goal used? -->

## Changeset

<!-- List what was added, removed, or changed.  Pitch this at a level 
     appropriate to the scope of the change: new  classes, changed architecture,
     minor typo, etc.  If appropriate include a list of changed files: 

         $ git diff --name-status HEAD~1 | cat
-->

## Tests

<!-- How was this change tested? What manual and automated tests were
     run/added? -->

## Review

### Outstanding Questions

<!-- Are there any parts of the design or the implementation which seem
     less than ideal and that could require additional discussion?
     List here: -->

<!-- Preflight checks. Have I:

* Added a changelog entry?
* Checked the scope to ensure the commits are only related to the goal above?

-->

- This pull request is ready for:
  - [ ] Initial review of the intended approach, not yet feature complete
  - [ ] Structural review of the classes, functions, and properties modified
  - [ ] Final review
  - [ ] Release

<!-- What do you need from a reviewer to get this changeset
     ready for release -->

- [ ] The correct target branch has been selected (`master` for fixes, `next` for
  features)
- [ ] If this is intended for release have all of the [pre-release checks](CONTRIBUTING.md) been considered?
- [ ] Consistency across platforms for structures or concepts added or modified
- [ ] Consistency between the changeset and the goal stated above
- [ ] Internal consistency with the rest of the library - is there any overlap between existing interfaces and any which have been added?
- [ ] Usage friction - is the proposed change in usage cumbersome or complicated?
- [ ] Performance and complexity - are there any cases of unexpected O(n^3) when iterating, recursing, flat mapping, etc?
- [ ] Concurrency concerns - if components are accessed asynchronously, what issues will arise
- [ ] Thoroughness of added tests and any missing edge cases
- [ ] Idiomatic use of the language
