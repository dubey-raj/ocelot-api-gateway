using Microsoft.AspNetCore.Mvc;

namespace APIGateway.Controllers
{
    [Route("")]
    [ApiController]
    public class RootController : ControllerBase
    {
        [HttpGet]
        public RedirectResult Get() => Redirect("/swagger");
    }
}
