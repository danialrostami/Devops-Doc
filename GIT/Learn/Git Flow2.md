## Gitflow Workflow Graph

```mermaid
%% Atlassian-style Gitflow Graph
%% Main, Develop, Feature, Release, Hotfix branches

flowchart TD
    %% Main branch
    M(Main / Production)
    D(Develop / Integration)

    %% Features
    F1[feature/login]
    F2[feature/payment]
    F3[feature/ui]

    %% Release
    R1[release/1.0.0]

    %% Hotfix
    H1[hotfix/urgent-bug]

    %% Timeline arrows
    M --> D
    D --> F1 --> D
    D --> F2 --> D
    D --> F3 --> D
    D --> R1 --> M
    R1 --> D
    M --> H1 --> M
    H1 --> D

    %% Styling for clarity
    classDef main fill:#f9f,stroke:#333,stroke-width:2px;
    classDef develop fill:#9f9,stroke:#333,stroke-width:2px;
    classDef feature fill:#ff9,stroke:#333,stroke-width:2px;
    classDef release fill:#9ff,stroke:#333,stroke-width:2px;
    classDef hotfix fill:#f99,stroke:#333,stroke-width:2px;

    class M main
    class D develop
    class F1,F2,F3 feature
    class R1 release
    class H1 hotfix
