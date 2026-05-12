# Update Deamon

This is a simple utility server that supports a simple continuous delivery system. The config can be used to describe multiple projects for updates. The options are:

- Project Path - The folder path to the project
- Secret - The Sha3 256 hashed secret. Store the unhashed version in the CI and send it so that it gets compared to the local hash.
- Match - You can put the commands to run for gievn file name that was received.
