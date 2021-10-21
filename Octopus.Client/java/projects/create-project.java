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

public class CreateProject {

  static final String octopusServerUrl = "http://localhost:8065";
  // as read from your profile in your Octopus Deploy server
  static final String apiKey = System.getenv("OCTOPUS_SERVER_API_KEY");

  public static void main(final String... args) throws IOException {
    final OctopusClient client = createClient();

    final Repository repo = new Repository(client);
    final Optional<Space> space = repo.spaces().getByName("TheSpaceName");

    if (!space.isPresent()) {
      System.out.println("No space named 'TheSpaceName' exists on server");
      return;
    }

    final Optional<Lifecycle> lifecycle = space.get().lifecycles().getByName("TheLifecycleName");
    if (!lifecycle.isPresent()) {
      System.out.println("No lifecycle named 'TheLifecycleName' exists on server");
      return;
    }

    final Optional<ProjectGroup> projGroup =
        space.get().projectGroups().getByName("TheProjectGroupName");
    if (!projGroup.isPresent()) {
      System.out.println("No ProjectGroup named 'TheProjectGroupName' exists on server");
      return;
    }

    final ProjectResource projectToCreate =
        new ProjectResource(
            "TheProjectName",
            lifecycle.get().getProperties().getId(),
            projGroup.get().getProperties().getId());
    projectToCreate.setAutoCreateRelease(false);

    final Project createdProject = space.get().projects().create(projectToCreate);
  }

  // Create an authenticated connection to your Octopus Deploy Server
  private static OctopusClient createClient() throws MalformedURLException {
    final Duration connectTimeout = Duration.ofSeconds(10L);
    final ConnectData connectData =
        new ConnectData(new URL(octopusServerUrl), apiKey, connectTimeout);
    final OctopusClient client = OctopusClientFactory.createClient(connectData);

    return client;
  }
}