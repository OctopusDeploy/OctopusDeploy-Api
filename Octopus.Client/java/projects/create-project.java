import com.octopus.sdk.Repository;
import com.octopus.sdk.domain.Lifecycle;
import com.octopus.sdk.domain.Project;
import com.octopus.sdk.domain.ProjectGroup;
import com.octopus.sdk.domain.Space;
import com.octopus.sdk.http.ConnectData;
import com.octopus.sdk.http.OctopusClient;
import com.octopus.sdk.http.OctopusClientFactory;
import com.octopus.sdk.model.project.ProjectResource;
import java.io.IOException;
import java.net.MalformedURLException;
import java.net.URL;
import java.time.Duration;
import java.util.Optional;
public class CreateProjectExample {
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
    final Optional<Lifecycle> lifecycle = space.get().lifecycles().getByName("MyLifecycle");
    if(!lifecycle.isPresent()) {
      System.out.println("No lifecycle named 'MyLifecycle' exists on server");
      return;
    }
    final Optional<ProjectGroup> projGroup = space.get().projectGroups().getByName("MyProjectGroup");
    if(!projGroup.isPresent()) {
      System.out.println("No lifecycle named 'MyProjectGroup' exists on server");
      return;
    }
    final ProjectResource projectToCreate = new ProjectResource("Test Project",
        lifecycle.get().getProperties().getId(),
        projGroup.get().getProperties().getId());
    projectToCreate.setAutoCreateRelease(false);
    final Project createdProject = space.get().projects().create(projectToCreate);
  }
  // Create an authenticated connection to your Octopus Deploy Server
  private static OctopusClient createClient() throws MalformedURLException {
    final Duration connectTimeout = Duration.ofSeconds(10L);
    final ConnectData connectData = new ConnectData(new URL(octopusServerUrl), apiKey, connectTimeout);
    final OctopusClient client = OctopusClientFactory.createClient(connectData);
    return client;
  }
}