import { Service } from "diod";
import { Row } from "postgres";

import { PostgresConnection } from "../../../shared/infrastructure/postgres/PostgresConnection";
import { PostgresRepository } from "../../../shared/infrastructure/postgres/PostgresRepository";
import { Product } from "../domain/Product";
import { ProductId } from "../domain/ProductId";
import { ProductName } from "../domain/ProductName";
import { ProductRepository } from "../domain/ProductRepository";

@Service()
export class PostgresProductRepository
	extends PostgresRepository<Product>
	implements ProductRepository
{
	// eslint-disable-next-line @typescript-eslint/no-useless-constructor
	constructor(connection: PostgresConnection) {
		super(connection);
	}

	async save(product: Product): Promise<void> {
		const primitives = product.toPrimitives();

		await this.execute`
			INSERT INTO pantry.products (id, name, current_stock, last_updated)
			VALUES (
				${primitives.id}::uuid,
				${primitives.name},
				${primitives.currentStock},
				${primitives.lastUpdated}::timestamp
			)
			ON CONFLICT (name_normalized) DO UPDATE
			SET
				current_stock = EXCLUDED.current_stock,
				last_updated = EXCLUDED.last_updated;
		`;
	}

	async searchById(id: ProductId): Promise<Product | null> {
		return this.searchOne`
			SELECT id, name, current_stock, last_updated
			FROM pantry.products
			WHERE id = ${id.value}::uuid;
		`;
	}

	async searchAll(): Promise<Product[]> {
		return this.searchMany`
			SELECT id, name, current_stock, last_updated
			FROM pantry.products
			ORDER BY name ASC;
		`;
	}

	async searchByName(name: ProductName): Promise<Product | null> {
		return this.searchOne`
			SELECT id, name, current_stock, last_updated
			FROM pantry.products
			WHERE name_normalized = LOWER(${name.value});
		`;
	}

	protected toAggregate(row: Row): Product {
		return Product.fromPrimitives({
			id: row.id as string,
			name: row.name as string,
			currentStock: row.current_stock as number,
			lastUpdated: row.last_updated as string,
		});
	}
}
