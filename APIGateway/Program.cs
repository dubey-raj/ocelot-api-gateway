using Ocelot.DependencyInjection;
using Ocelot.Middleware;

var builder = WebApplication.CreateBuilder(args);

//Add configuration for ocelot
builder.Configuration.AddJsonFile("ocelot.json", optional: false, reloadOnChange: true);

// Add services to the container.
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddOcelot();
builder.Services.AddSwaggerForOcelot(builder.Configuration);
builder.Services.AddCors();

var app = builder.Build();
//app.UseHttpsRedirection();
app.MapControllers();
app.UseCors(policy => policy
.AllowAnyMethod()
.AllowAnyHeader()
.AllowAnyOrigin()
);
app.UseSwaggerForOcelotUI(opt =>
{
    opt.PathToSwaggerGenerator = "/swagger/docs";
});
await app.UseOcelot();

app.Run();
