import com.octopus.sdk.Repository;
import com.octopus.sdk.domain.Project;
import com.octopus.sdk.domain.Release;
import com.octopus.sdk.domain.Space;
import com.octopus.sdk.http.ConnectData;
import com.octopus.sdk.http.OctopusClient;
import com.octopus.sdk.http.OctopusClientFactory;
import com.octopus.sdk.model.release.ReleaseResource;
import java.io.IOException;
import java.net.MalformedURLException;
import java.net.URL;
import java.time.Duration;
import java.util.Optional;
public class CreateReleaseWithVersion {
  final static String octopusServerUrl = "http://localhost:8065";
  final static String apiKey = "YOUR_API_KEY"; // as read from your profile in your Octopus Deploy server
  public static void main(final String... args) throws IOException {
    final OctopusClient client = createClient();
    final Repository repo = new Repository(client);
    final Optional<Space> space = repo.spaces().getByName("TheSpaceName");
    if(!space.isPresent()) {
      System.out.println("No space named 'TheSpaceName' exists on server");
      return;
    }
    final Optional<Project> project = space.get().projects().getByName("TheProjectName");
    if(!project.isPresent()) {
      System.out.println("No project named 'TheProjectName' exists on server");
      return;
    }
    final ReleaseResource releaseResource = new ReleaseResource("1.0", project.get().getProperties().getId());
    final Release release = space.get().releases().create(releaseResource);
  }
  // Create an authenticated connection to your Octopus Deploy Server
  private static OctopusClient createClient() throws MalformedURLException {
    final Duration connectTimeout = Duration.ofSeconds(10L);
    final ConnectData connectData = new ConnectData(new URL(octopusServerUrl), apiKey, connectTimeout);
    final OctopusClient client = OctopusClientFactory.createClient(connectData);
    return client;
  }
}