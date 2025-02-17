using APIGateway.Middlewares;
using MMLib.SwaggerForOcelot.Configuration;
using Ocelot.DependencyInjection;
using Ocelot.Middleware;

var builder = WebApplication.CreateBuilder(args);

//Add configuration for ocelot
var environment = builder.Environment.EnvironmentName;

if (environment?.ToLower() == "local")
{
    builder.Configuration.AddJsonFile($"ocelot.local.json", optional: false, reloadOnChange: true);
}
else
{
    builder.Configuration.AddJsonFile($"ocelot.json", optional: false, reloadOnChange: true);
}

// Add services to the container.
builder.Services.AddTransient<GlobalExceptionMiddleware>();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddOcelot();
builder.Services.AddSwaggerForOcelot(builder.Configuration);
builder.Services.AddCors();

var app = builder.Build();

app.MapControllers();
app.UseRouting();
app.UseEndpoints(endpoints =>
{
    endpoints.MapGet("/healthz", async context =>
    {
        await context.Response.WriteAsync("Success");
    });
});
app.UseCors(policy => policy
.AllowAnyMethod()
.AllowAnyHeader()
.AllowAnyOrigin()
);
app.UseMiddleware<GlobalExceptionMiddleware>();
app.UseSwagger();
app.UseSwaggerForOcelotUI(opt =>
{
    opt.PathToSwaggerGenerator = "/swagger/docs";
    opt.DownstreamSwaggerEndPointBasePath = "/swagger/docs";
}).UseOcelot().Wait();
app.UseOcelot().Wait();

app.Run();
