import { AggregateRoot } from "../../../shared/domain/AggregateRoot";

import { ProductId } from "./ProductId";
import { ProductName } from "./ProductName";
import { ProductStock } from "./ProductStock";

export interface ProductPrimitives {
	id: string;
	name: string;
	currentStock: number;
	lastUpdated: string;
}

export class Product extends AggregateRoot {
	private readonly name: ProductName;
	private stock: ProductStock;
	private lastUpdated: Date;

	constructor(
		readonly id: ProductId,
		name: string,
		currentStock: number,
		lastUpdated?: Date,
	) {
		super();
		this.name = new ProductName(name);
		this.stock = new ProductStock(currentStock);
		this.lastUpdated = lastUpdated ?? new Date();
	}

	static create(id: string, name: string, currentStock: number): Product {
		const product = new Product(new ProductId(id), name, currentStock);

		return product;
	}

	static fromPrimitives(primitives: ProductPrimitives): Product {
		return new Product(
			new ProductId(primitives.id),
			primitives.name,
			primitives.currentStock,
			new Date(primitives.lastUpdated),
		);
	}

	updateStock(stock: ProductStock): void {
		this.stock = stock;
		this.lastUpdated = new Date();
	}

	toPrimitives(): ProductPrimitives {
		return {
			id: this.id.value,
			name: this.name.value,
			currentStock: this.stock.value,
			lastUpdated: this.lastUpdated.toISOString(),
		};
	}
}
