using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace DevOpsLab.WebApi.Endpoints;

public static class DebugEndpoints
{
    public static IEndpointRouteBuilder MapDebugEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/debug/search", async (string query, IConfiguration configuration) =>
        {
            var connectionString = configuration.GetConnectionString("Default");
            using var connection = new SqlConnection(connectionString);
            await connection.OpenAsync();

            // Intentional SQL Injection vulnerability for CodeQL demonstration
            string sql = "SELECT * FROM Products WHERE Name = '" + query + "'";
            using var command = new SqlCommand(sql, connection);
            using var reader = await command.ExecuteReaderAsync();

            return Results.Ok("Search completed");
        });

        return app;
    }
}
