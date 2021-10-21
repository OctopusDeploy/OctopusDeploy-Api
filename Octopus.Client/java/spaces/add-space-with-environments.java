import com.octopus.sdk.Repository;
import com.octopus.sdk.domain.Environment;
import com.octopus.sdk.domain.Space;
import com.octopus.sdk.domain.User;
import com.octopus.sdk.http.ConnectData;
import com.octopus.sdk.http.OctopusClient;
import com.octopus.sdk.http.OctopusClientFactory;
import com.octopus.sdk.model.environment.EnvironmentResource;
import com.octopus.sdk.model.space.SpaceOverviewResource;

import java.io.IOException;
import java.net.MalformedURLException;
import java.net.URL;
import java.time.Duration;
import java.util.Set;

import com.google.common.collect.Sets;

public class AddSpaceWithEnvironments {

  static final String octopusServerUrl = "http://localhost:8065";
  // as read from your profile in your Octopus Deploy server
  static final String apiKey = System.getenv("OCTOPUS_SERVER_API_KEY");

  public static void main(final String... args) throws IOException {
    final OctopusClient client = createClient();

    final Repository repo = new Repository(client);
    final User currentUser = repo.users().getCurrentUser();
    final Set<String> spaceManagers = Sets.newHashSet(currentUser.getProperties().getId());
    final Space createdSpace =
        repo.spaces().create(new SpaceOverviewResource("TheSpaceName", spaceManagers));
    final Environment testEnv = createdSpace.environments().create(new EnvironmentResource("Test"));
    final Environment prodEnv =
        createdSpace.environments().create(new EnvironmentResource("Production"));
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