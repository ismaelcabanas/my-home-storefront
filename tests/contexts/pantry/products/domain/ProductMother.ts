import {
	Product,
	ProductPrimitives,
} from "../../../../../src/contexts/pantry/products/domain/Product";

import { ProductIdMother } from "./ProductIdMother";
import { ProductNameMother } from "./ProductNameMother";
import { ProductStockMother } from "./ProductStockMother";

export class ProductMother {
	static create(params?: Partial<ProductPrimitives>): Product {
		const primitives: ProductPrimitives = {
			id: ProductIdMother.create().value,
			name: ProductNameMother.create().value,
			currentStock: ProductStockMother.create().value,
			lastUpdated: new Date().toISOString(),
			...params,
		};

		return Product.fromPrimitives(primitives);
	}
}
