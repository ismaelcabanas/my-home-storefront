import { Product } from "../../../../../src/contexts/pantry/products/domain/Product";
import { ProductId } from "../../../../../src/contexts/pantry/products/domain/ProductId";
import { ProductName } from "../../../../../src/contexts/pantry/products/domain/ProductName";
import { ProductRepository } from "../../../../../src/contexts/pantry/products/domain/ProductRepository";

export class MockProductRepository implements ProductRepository {
	private readonly mockSave = jest.fn();
	private readonly mockSearchById = jest.fn();
	private readonly mockSearchAll = jest.fn();
	private readonly mockSearchByName = jest.fn();

	async save(product: Product): Promise<void> {
		const expected = this.mockSave.mock.calls[0]?.[0];
		if (
			expected &&
			typeof expected === "object" &&
			"asymmetricMatch" in expected
		) {
			// Expected is a Jest matcher, use it directly
			expect(this.mockSave).toHaveBeenCalledWith(expected);
		} else {
			// Expected is the actual primitives, compare values (excluding timestamp)
			const actual = product.toPrimitives();
			if (expected) {
				expect(actual.id).toBe(expected.id);
				expect(actual.name).toBe(expected.name);
				expect(actual.currentStock).toBe(expected.currentStock);
			}
		}

		return Promise.resolve();
	}

	shouldSave(product: Product): void {
		const primitives = product.toPrimitives();
		this.mockSave({
			id: primitives.id,
			name: primitives.name,
			currentStock: primitives.currentStock,
		});
	}

	async searchById(_id: ProductId): Promise<Product | null> {
		return this.mockSearchById() as Product | null;
	}

	shouldSearchByIdReturn(product: Product | null): void {
		this.mockSearchById.mockReturnValue(product);
	}

	async searchAll(): Promise<Product[]> {
		return this.mockSearchAll() as Product[];
	}

	shouldSearchAllReturn(products: Product[]): void {
		this.mockSearchAll.mockReturnValue(products);
	}

	async searchByName(_name: ProductName): Promise<Product | null> {
		return this.mockSearchByName() as Product | null;
	}

	shouldSearchByNameReturn(product: Product | null): void {
		this.mockSearchByName.mockReturnValue(product);
	}
}
