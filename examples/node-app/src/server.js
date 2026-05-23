import http from 'node:http';

const port = Number.parseInt(process.env.PORT ?? '3000', 10);
const host = '0.0.0.0';

const server = http.createServer((_request, response) => {
    response.writeHead(200, { 'Content-Type': 'application/json' });
    response.end(
        JSON.stringify({
            service: 'sakala-example-node-app',
            status: 'ok',
        }),
    );
});

server.listen(port, host, () => {
    console.log(`sakala-example-node-app listening on ${host}:${port}`);
});
