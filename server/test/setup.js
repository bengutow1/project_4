// Runs before every test file (see "setupFilesAfterEnv" in package.json).
// Any fetch a test hasn't mocked fails loudly instead of calling the real
// Open-Meteo API, so CI never depends on the network.
beforeEach(() => {
  jest.spyOn(global, 'fetch').mockImplementation(async (url) => {
    const message = `Unmocked fetch in a test: ${url}. Mock it with jest.spyOn(global, 'fetch').`;
    // The server turns fetch errors into a 502, so say why here too.
    console.error(message);
    throw new Error(message);
  });
});
