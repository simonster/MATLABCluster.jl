module MATLABCluster

using MATLAB

export MATLABManager
import Base.readline

immutable MATLABManager <: ClusterManager
    profile::ASCIIString
end
MATLABManager() = MATLABManager("")

type ConnectionInfoIOHack <: IO
    conninfo::ByteString
    line_buffered::Bool # unused
end
ConnectionInfoIOHack(conninfo) = ConnectionInfoIOHack(conninfo, true)
readline(x::ConnectionInfoIOHack) = x.conninfo

# Read the file written by diary and check if Julia is running
function get_worker_info(diary)
    for l in split(diary, '\n')
        private_hostname, port = Base.parse_connection_info(l)
        if private_hostname != ""
            return ConnectionInfoIOHack(l)
        end
    end
end

function Base.launch(cman::MATLABManager, np::Integer, config::Dict, instances_arr::Array, c::Condition)
    try
        exe = Base.shell_escape("$(config[:dir])/$(config[:exename])")
        exeflags = Base.shell_escape(config[:exeflags].exec...)
        cmd = replace("LD_LIBRARY_PATH= OMP_NUM_THREADS=1 $exe $exeflags", "'", "''")

        # Start MATLAB jobs
        jobvar = "jobs_$(randstring(12))"
        eval_string("""
            clust = parcluster($(cman.profile != "" ? "'$(cman.profile)'" : ""));
            username = clust.Username;
            host = clust.Host;

            j = createJob(clust);
            $jobvar = cell($np, 1);
            for i = 1:$(np)
                $jobvar{i} = createTask(j, @() system('$cmd', '-echo'), 0, {}, 'CaptureDiary', true);
            end
            submit(j);
        """)

        @mget username host

        print("Waiting for jobs to start...")
        for i = 1:np
            # Wait until MATLAB says job is running
            eval_string("""
                j = $jobvar{$i};
                wait(j, 'running')
            """)

            # Hack to wait until Julia is running
            local worker_info
            while true
                eval_string("""
                    state = j.State;
                    warning('off', 'all');
                    diary = j.Diary;
                    if isempty(diary)
                        diary = ' ';
                    end
                    warning('on', 'all');
                """)
                @mget state diary

                if state == "finished"
                    error("task failed:\n$diary")
                else
                    worker_info = get_worker_info(diary)
                    worker_info == nothing || break
                end
                # sleep(0.25)
            end
            inst = (worker_info, "$username@$host", merge(config, Dict(:jobvar => jobvar, :jobindex => i)))
            push!(instances_arr, (inst,))
            notify(c)
        end
        print("done\n")
    catch e
        showerror(STDERR, e, catch_backtrace())
        println()
        rethrow(e)
    end
    notify(c)
end

function Base.manage(cman::MATLABManager, id::Integer, config::Dict, op::Symbol)
    if op == :finalize
        eval_string("delete($(config[:jobvar]){$(config[:jobindex])});")
    end
end

end # module
