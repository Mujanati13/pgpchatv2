import './App.css'

function App() {
  const requestEmail = 'support@pgpchat.app'
  const deleteRequestLink = `mailto:${requestEmail}?subject=Account%20Deletion%20Request`

  return (
    <main className="page">
      <section className="card" aria-labelledby="delete-account-title">
        <h1 id="delete-account-title">Delete Your PGP Chat Account</h1>
        <p className="lead">
          Use the link below to request deletion of your account and associated data.
        </p>

        <a className="request-link" href={deleteRequestLink}>
          Request Account Deletion
        </a>

        <p className="contact">
          If the link does not open, email us directly at <strong>{requestEmail}</strong>.
        </p>

        <h2>What to include in your request</h2>
        <ul>
          <li>Your registered email address or username</li>
          <li>Deletion request from the same registered email when possible</li>
          <li>Any relevant details needed to identify your account</li>
        </ul>
      </section>
    </main>
  )
}

export default App
