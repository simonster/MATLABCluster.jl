module MatlabCluster

using MATLAB

export MatlabClusterManager
import Base.readline

immutable MatlabClusterManager <: ClusterManager
    profile::ASCIIString
    launch::Function
    manage::Function
end
MatlabClusterManager(profile::ASCIIString="") =
    MatlabClusterManager(profile, launch_matlab_workers, manage_matlab_worker)

type ConnectionInfoIOHack <: IO
    conninfo::ByteString
    line_buffered::Bool # unused
end
ConnectionInfoIOHack(conninfo::ByteString) = ConnectionInfoIOHack(conninfo, true)
readline(x::ConnectionInfoIOHack) = x.conninfo

# Read the file written by diary and check if Julia is running
function read_worker_info(io)
    seek(io, 0)
    try
        for l in eachline(io)
            private_hostname, port = Base.parse_connection_info(l)
            if private_hostname != ""
                return ConnectionInfoIOHack(l)
            end
        end
    finally
        truncate(io, 0)
    end
    nothing
end

function launch_matlab_workers(cman::MatlabClusterManager, np::Integer, config::Dict)
    exe = Base.shell_escape("$(config[:dir])/$(config[:exename])")
    exeflags = Base.shell_escape(config[:exeflags].exec...)
    cmd = replace("LD_LIBRARY_PATH= OMP_NUM_THREADS=1 $exe $exeflags", "'", "''")

    # Start MATLAB jobs
    jobvar = "jobs_$(randstring(12))"
    eval_string("""
        clust = parcluster($(cman.profile != "" ? "'$(cman.profile)'" : ""));
        username = clust.Username;
        host = clust.Host;

        $jobvar = {};
        for i = 1:$(np)
            j = batch(clust, @() system('$cmd', '-echo'), 0, 'CurrentFolder', '.', 'CaptureDiary', true);
            $jobvar{end+1} = j;
        end
    """)

    @mget username host

    print("Waiting for jobs to start...")
    tmppath, tmpio = mktemp()
    infos = cell(np)
    try
        for i = 1:np
            # Wait until MATLAB says job is running
            eval_string("""
                j = $jobvar{$i};
                wait(j, 'running');
            """)

            # Hack to wait until Julia is running
            local worker_info
            while true
                eval_string("""
                    state = j.State;
                    warning('off', 'all');
                    diary(j, '$tmppath');
                    warning('on', 'all');
                """)
                @mget state

                if state == "finished"
                    seek(tmpio, 0)
                    error("job failed:\n$(chomp(readall(tmpio)))")
                else
                    worker_info = read_worker_info(tmpio)
                    worker_info == nothing || break
                end
                sleep(0.5)
            end
            infos[i] = worker_info
            print(".")
        end
    finally
        close(tmpio)
        rm(tmppath)
    end
    println()

    (:io_host, [(infos[i], "$username@$host", merge(config, {:jobvar => jobvar, :jobindex => i})) for i = 1:np])
end

function manage_matlab_worker(id::Integer, config::Dict, op::Symbol)
    if op == :finalize
        eval_string("delete($(config[:jobvar]){$(config[:jobindex])});")
    end
end

end # module
