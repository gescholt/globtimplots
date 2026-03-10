module GlobtimDataExt

using GlobtimPlots
import CSV, DataFrames

# Extend the stub functions from Globtim
"""
    load_data(filepath::String) -> DataFrames.DataFrame

Load data from CSV file when CSV and DataFrames are available.
"""
function load_data(filepath::String)
    return CSV.read(filepath, DataFrames.DataFrame)
end

"""
    save_data(data::DataFrames.DataFrame, filepath::String)

Save DataFrame to CSV file when CSV and DataFrames are available.
"""
function save_data(data::DataFrames.DataFrame, filepath::String)
    CSV.write(filepath, data)
end

"""
    create_results_dataframe() -> DataFrames.DataFrame

Create a standard results dataframe structure.
"""
function create_results_dataframe()
    return DataFrames.DataFrame(
        function_name = String[],
        critical_points = Int[],
        computation_time = Float64[],
        degree = Int[],
        samples = Int[]
    )
end

end