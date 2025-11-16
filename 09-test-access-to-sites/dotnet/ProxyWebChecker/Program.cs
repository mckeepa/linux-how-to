using System;
using System.IO;
using System.Net.Http;
using System.Net;
using System.Threading.Tasks;
using System.Security.Principal;

class Program
{
    static async Task Main(string[] args)
    {
        string csvPath = "input.csv";

        if (!File.Exists(csvPath))
        {
            Console.WriteLine("CSV file not found.");
            return;
        }

        var lines = File.ReadAllLines(csvPath);

        // Skip the header
        for (int i = 1; i < lines.Length; i++)
        {
            var parts = lines[i].Split(',');

            if (parts.Length != 3)
            {
                Console.WriteLine($"Invalid line format at line {i + 1}");
                continue;
            }

            string userId = parts[0];
            string access = parts[1];
            string siteUrl = parts[2];

            // Skip if access is denied
            // if (access.Equals("Denied", StringComparison.OrdinalIgnoreCase))
            // {
            //     Console.WriteLine($"User {userId} is denied access to {siteUrl}");
            //     continue;
            // }

            // Console.WriteLine($"Impersonating user: {userId}");

            // Use impersonation logic here if possible
            // This block is placeholder — requires real domain users and setup

        
////////////////////////////////
///   // 1. Create a NetworkCredential object for the proxy server
        var proxyCredentials = new NetworkCredential(userId, "proxyPassword");

        // 2. Create a WebProxy object and assign the proxy address and credentials
        var webProxy = new WebProxy
        {
            Address = new Uri($"http://{proxyAddress}:{proxyPort}"),
            Credentials = proxyCredentials,
            BypassProxyOnLocal = false // Set to true if you want to bypass proxy for local addresses
        };

        // 3. Create an HttpClientHandler and assign the WebProxy
        var handler = new HttpClientHandler
        {
            Proxy = webProxy,
            UseProxy = true // Ensure proxy usage is enabled
        };

        // 4. Create an HttpClient instance with the configured handler
        using (var client = new HttpClient(handler))
        {
            // 5. Make the request to the target URL
            try
            {
                var response = await client.GetStringAsync(targetUrl);
                Console.WriteLine($"Response from {targetUrl} through proxy: {response}");
            }
            catch (HttpRequestException e)
            {
                Console.WriteLine($"Error calling {targetUrl}: {e.Message}");
            }
        }



////////////////////////////////////////////
            try
            {
                var result = await PerformWebRequest(siteUrl);
                Console.WriteLine($"xxx User: {userId} | URL: {siteUrl} | Success: {result}| Expected: {access}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"User: {userId} | URL: {siteUrl} | Error: {ex.Message} | Expected: {access}");
            }
        }
    }

    static async Task<bool> PerformWebRequest(string url)
    {
        using var handler = new HttpClientHandler()
        {
            UseDefaultCredentials = true // This allows system user identity to pass through (NTLM/Kerberos)
        };

        using var client = new HttpClient(handler);
        var response = await client.GetAsync(url);
        return response.IsSuccessStatusCode;
    }
}
