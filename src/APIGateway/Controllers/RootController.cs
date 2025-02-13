using Microsoft.AspNetCore.Mvc;

namespace APIGateway.Controllers
{
    [ApiExplorerSettings(IgnoreApi = true)]
    [Route("")]
    [ApiController]
    public class RootController : ControllerBase
    {
        [HttpGet]
        public RedirectResult Get() => Redirect("/swagger");

        /// <summary>
        /// Returns response for healthz query
        /// </summary>
        /// <returns>OK 200</returns>
        [Route("healthz")]
        [HttpGet]
        public ObjectResult GetHealth() => Ok("Success");
    }
}
