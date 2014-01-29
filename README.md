# MATLABCluster.jl

The `MATLABCluster.jl` package provides an interface for starting [Julia](http://www.julialang.org/) worker processes using [MATLAB™ Parallel Computing Toolbox](http://www.mathworks.com/help/distcomp/index.html) cluster profiles, including profiles configured to connect to a [MATLAB™ Distributed Computing Server](http://www.mathworks.com/products/distriben/index.html). You cannot use `MATLABCluster.jl` without having purchased and installed a copy of MATLAB™ and the MATLAB™ Parallel Computing Toolbox from [MathWorks](http://www.mathworks.com/). This package is available free of charge and in no way replaces or alters any functionality of MathWorks's MATLAB product.

To connect to a MATLAB cluster:

```julia
using MATLABCluster
addprocs(1,                               # The number of workers you want
         dir="/path/to/julia/usr/bin",    # Path to Julia on your cluster
         cman=MATLABManager("profile"),   # The cluster profile, set up within MATLAB
         tunnel=true,                     # Only necessary if the workers are behind NAT
         sshflags=`-c blowfish`           # Only for NAT; faster than AES (default)
        )
```

## Caveats

- Currently output from the workers is not transmitted back to Julia
- This may not work if the MATLAB Job Scheduler is running on Windows (but let me know if you try)
