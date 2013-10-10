# MatlabCluster.jl

To connect to a MATLAB Job Scheduler cluster:

```julia
using MatlabCluster
addprocs(1,                                    # The number of workers you want
         dir="/path/to/julia/usr/bin",         # Path to Julia on your cluster
         cman=MatlabClusterManager("profile"), # The cluster profile, set up within MATLAB
         tunnel=true,                          # Only necessary if the workers are behind NAT
         sshflags=`-c blowfish`                # Only for NAT; faster than AES (default)
        )
```

## Caveats

- Currently output from the workers is not transmitted back to Julia
- This may not work if MJS is running on Windows (but let me know if you try)
