const assert = require('node:assert/strict');
const {createRequire} = require('node:module');
const req = createRequire('/usr/src/app/server/package.json');
const {z} = req('zod');
const {createZodDto, cleanupOpenApiDoc} = req('nestjs-zod');

const Query = createZodDto(z.object({query: z.string().optional()}).meta({id: 'PilotQuery'}));
const metadata = Query._OPENAPI_METADATA_FACTORY();
assert.ok(metadata.query, 'named query DTO lost its properties');
assert.equal(metadata.root, undefined, 'named query DTO became a non-object wrapper');

const Nullable = createZodDto(z.object({value: z.string().nullable()}).meta({id: 'PilotNullable'}));
const nullable = Nullable._OPENAPI_METADATA_FACTORY().value;
assert.deepEqual(nullable.anyOf.map((branch) => branch.type), ['string', 'null']);
assert.equal(nullable.items, undefined, 'nullable primitive became an array');

// This is the pinned library's own metadata protocol, as emitted by its DTO factory.
const marker = 'x-nestjs_zod-parent-id';
const conflict = {
  openapi: '3.0.0', paths: {}, components: {schemas: {
    First: {type: 'object', properties: {a: {type: 'string', [marker]: 'PilotConflict'}}},
    Second: {type: 'object', properties: {b: {type: 'integer', [marker]: 'PilotConflict'}}},
  }},
};
assert.throws(() => cleanupOpenApiDoc(conflict), /multiple schemas with name `PilotConflict`/);
console.log('PASS: named query DTO, nullable primitive and genuine schema collision rejection');

async function recursiveSchemaTest() {
  const {Controller, Get, Module, Query: QueryParameter} = req('@nestjs/common');
  const {NestFactory} = req('@nestjs/core');
  const {ApiOkResponse, SwaggerModule, DocumentBuilder} = req('@nestjs/swagger');
  let tree;
  tree = z.object({
    state: z.enum(['alpha', 'beta']).nullable(),
    mixed: z.union([z.string().min(1), z.number().positive()]).nullable(),
    children: z.array(z.lazy(() => tree)).optional(),
  }).meta({id: 'PilotTree'});
  const Tree = createZodDto(tree);
  class ProbeController { get(query) { return query; } }
  Controller('schema-probe')(ProbeController);
  const target = ProbeController.prototype;
  const descriptor = Object.getOwnPropertyDescriptor(target, 'get');
  Get()(target, 'get', descriptor);
  QueryParameter()(target, 'get', 0);
  Reflect.defineMetadata('design:paramtypes', [Tree], target, 'get');
  ApiOkResponse({type: Tree})(target, 'get', descriptor);
  class ProbeModule {}
  Module({controllers: [ProbeController]})(ProbeModule);
  const app = await NestFactory.create(ProbeModule, {logger: false});
  try {
    await app.init();
    const doc = cleanupOpenApiDoc(SwaggerModule.createDocument(app, new DocumentBuilder().build()));
    const root = doc.components.schemas.PilotTree;
    assert.equal(root.type, 'object');
    assert.equal(root.properties.state.nullable, true);
    assert.deepEqual(root.properties.state.enum.filter((value) => value !== null), ['alpha', 'beta']);
    assert.ok(root.properties.mixed.anyOf.some((branch) => branch.type === 'string' && branch.minLength === 1));
    assert.ok(root.properties.mixed.anyOf.some((branch) => branch.type === 'number'));
    const check = (value) => {
      if (!value || typeof value !== 'object') return;
      if (value.$ref?.startsWith('#/components/schemas/')) {
        assert.ok(doc.components.schemas[value.$ref.slice('#/components/schemas/'.length)], value.$ref);
      }
      for (const child of Object.values(value)) check(child);
    };
    check(doc);
    assert.equal(tree.safeParse({state: 'gamma', mixed: 1}).success, false);
    assert.equal(tree.safeParse({state: 'alpha', mixed: '', children: []}).success, false);
    assert.equal(tree.safeParse({state: null, mixed: 1, children: [{state: 'beta', mixed: 'x'}]}).success, true);
    console.log('PASS: real Nest query/response, recursive refs, nullable enum and constrained union');
  } finally { await app.close(); }
}
recursiveSchemaTest().catch((error) => {console.error(error); process.exitCode = 1;});
