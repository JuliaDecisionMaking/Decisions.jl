# Contributing to Decisions.jl

We enthusiastically welcome your contribution to the Decisions.jl ecosystem!
The project is currently in beta, and we'd appreciate both your code
contribution and your comments on how the framework could be improved.

There are several ways you can contribute. In all cases, follow [Github Flow](https://guides.github.com/introduction/flow/):

1. [Fork the repository](https://docs.github.com/en/github/getting-started-with-github/fork-a-repo)
2. [Create an issue](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/creating-an-issue) to discuss the proposed content / changes
3. Make the changes [on the github site](https://docs.github.com/en/github/managing-files-in-a-repository/editing-files-in-your-repository) or [with git on your computer](https://docs.github.com/en/github/getting-started-with-github/set-up-git).
4. [Open a pull request](https://docs.github.com/en/github/collaborating-with-issues-and-pull-requests/creating-a-pull-request-from-a-fork) to receive feedback, discuss, and merge the changes.

## Implementing a domain

If you have a research domain you'd like to implement in `Decisions.jl`, we'd
love to have it. Please open an issue to allow for discussion and assign
yourself to it. In particular, your comments on the framework while building
your domain are the primary goal here, so please leave them on your original
issue or, if applicable, open new issues to note any bugs, inconsistencies,
or annoyances.

If you'd like to write a domain but don't have a specific one in mind, have a
look at our [open issues](https://github.com/JuliaDecisionMaking/Decisions.jl/issues?q=is%3Aissue%20state%3Aopen%20label%3A%22help%20wanted%22%20label%3Adomains).

Domains live in `DecisionDomains.jl`. You can use `gridworld.jl` as a (very rough) template.


## Implementing a solver

Follow the same workflow as above if you have a decision making algorithm
you'd like to implement. All sorts of solvers are welcome, though we tend to
prioritize model-based, online algorithms that are particularly "archetypal"
or serve as templates for other algorithms. Note that you may need to define
a baseline to test it on as well, which might necessitate defining the
problem type (see the docs).

You can see our [open issues]
(https://github.com/JuliaDecisionMaking/Decisions.jl/issues?q=is%3Aissue%20state%3Aopen%20label%3A%22help%20wanted%22%20label%3Abaselines)
for the types of baseline solvers we have in mind currently.


## Testing the framework

Tests for this project are currently very lacking, and always needed. If
you're willing to write some tests, or help configure coverage reports, we
would be incredibly appreciative.



## Improving the documentation

Decisions.jl is documented with Documenter.jl. We are always looking for
improvements to the docs (and even just knowing which parts are confusing is
very valuable data for us, so don't shy away from opening an issue with the
`documentation` tag).

We are particularly looking for good [tutorial docs]
(https://docs.divio.com/documentation-system/) at the moment.


## Enhancements to the framework

A [number of our outstanding issues]
(https://github.com/JuliaDecisionMaking/Decisions.jl/issues?q=is%3Aissue%20state%3Aopen%20label%3A%22help%20wanted%22)
are labelled `help-wanted`. If you'd like to dive into the internals of the
project, these are a good place to start. We recommend you try a solver or
domain first to get a general level of familiarity with the code. (It's more
than likely you'll encounter a piece of functionality you'd like to implement
in the course of doing so.)

## Other tasks
* We'd appreciate it if you'd **watch** and **star** this repository to help
  increase the project's visibility.
