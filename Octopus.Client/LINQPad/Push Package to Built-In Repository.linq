<Query Kind="Program">
  <Namespace>System.Net</Namespace>
</Query>

void Main()
{
	// Pushes a package to the built-in repository using raw HTTP POST
	// Requires BuiltInFeedPush permission
	//
	// NOTE: Use Octopus.Client.OctopusRepository.BuiltInPackageRepositoryRepository.PushPackage() in Octopus 3.3
	//

	// 1. Your Octopus URL
	var octopusUrl = "https://octopus.url";

	// 2. An API key, preferably for a Service Account (http://docs.octopusdeploy.com/display/OD/Service+Accounts)
	var apiKey = "API-XXXXXXXXXXXXXXXXXXXXXX";

	// 3. Path to the package file to upload
	var packageFilePath = @"C:\Temp\HelloWorldWebApp.2.1.0.0.nupkg";

	// 4. true to overwrite existing packages (Requires: BuiltInFeedAdminister permission)
	var replaceExisting = false;

	var packageUrl = octopusUrl + "/api/packages/raw?replace=" + replaceExisting;
	Console.WriteLine("Uploading {0} to {1}", packageFilePath, packageUrl);

	var webRequest = (HttpWebRequest)WebRequest.Create(packageUrl);
	webRequest.Accept = "application/json";
	webRequest.ContentType = "application/json";
	webRequest.Method = "POST";
	webRequest.Headers["X-Octopus-ApiKey"] = apiKey;

	using (var packageFileStream = new FileStream(packageFilePath, FileMode.Open))
	{
		var requestStream = webRequest.GetRequestStream();

		var boundary = "----------------------------" + DateTime.Now.Ticks.ToString("x");
		var boundarybytes = Encoding.ASCII.GetBytes("\r\n--" + boundary + "\r\n");
		webRequest.ContentType = "multipart/form-data; boundary=" + boundary;
		requestStream.Write(boundarybytes, 0, boundarybytes.Length);

		var headerTemplate = "Content-Disposition: form-data; filename=\"{0}\"\r\nContent-Type: application/octet-stream\r\n\r\n";
		var header = string.Format(headerTemplate, Path.GetFileName(packageFilePath));
		var headerbytes = Encoding.UTF8.GetBytes(header);
		requestStream.Write(headerbytes, 0, headerbytes.Length);
		packageFileStream.CopyTo(requestStream);
		requestStream.Write(boundarybytes, 0, boundarybytes.Length);
		requestStream.Flush();
		requestStream.Close();
	}

	using (var webResponse = (HttpWebResponse)webRequest.GetResponse())
	{
		Console.WriteLine("{0} {1}", (int)webResponse.StatusCode, webResponse.StatusDescription);
	}
}
